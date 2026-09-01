#!/bin/bash

# This script collects repeatable Instruments evidence on the shared Mac.
# Think of it as a tiny checklist for Xcode: it records one trace, performs the
# matching user action, waits for Instruments to close the trace safely, and
# then moves to the next check. Keeping these steps in one script means another
# developer can repeat the same measurements instead of trusting a screenshot.

set -u
set -o pipefail

# With no arguments, the script uses the folder you are standing in and the
# first booted simulator. Advanced users can pass a repository path and a
# simulator UDID as arguments. This avoids baking one developer's Mac paths into
# a reusable project script.
REPOSITORY_PATH="${1:-$(pwd)}"
if [ "$#" -ge 2 ]; then
    SIMULATOR_ID="$2"
else
    SIMULATOR_ID=$(xcrun simctl list devices booted | awk '
        /\(Booted\)/ {
            value = $(NF - 1)
            gsub(/[()]/, "", value)
            print value
            exit
        }
    ')
fi

if [ -z "$SIMULATOR_ID" ]; then
    echo "No booted iOS simulator was found. Boot one in Xcode and try again."
    exit 2
fi

EVIDENCE_PATH="$REPOSITORY_PATH/EvidenceTraces"
DERIVED_DATA_PATH="$REPOSITORY_PATH/MacDerivedData"
BUNDLE_ID="in.sachinserver.News-App"
FAILURE_COUNT=0

cd "$REPOSITORY_PATH" || exit 2

# The folder is inside this disposable verification checkout. Removing only
# this exact folder prevents an older trace from being mistaken for today's
# result, because xctrace refuses to overwrite an existing .trace package.
rm -rf "$EVIDENCE_PATH"
mkdir -p "$EVIDENCE_PATH"

record_host_trace() {
    TEMPLATE_NAME="$1"
    TRACE_NAME="$2"
    TIME_LIMIT="$3"

    echo "STARTING_TRACE=$TRACE_NAME TEMPLATE=$TEMPLATE_NAME"
    # iOS Simulator applications are ARM processes running on the Mac. Xcode
    # 26.6 currently stalls when xctrace targets this simulator by UDID, so the
    # reliable command records those same CoreSimulator processes from the Mac
    # host. This is also how the Network instrument can see simulator traffic;
    # Apple marks Network Connections as unsupported for a simulator device.
    xcrun xctrace record \
        --quiet \
        --no-prompt \
        --template "$TEMPLATE_NAME" \
        --time-limit "$TIME_LIMIT" \
        --all-processes \
        --output "$EVIDENCE_PATH/$TRACE_NAME.trace" \
        >"$EVIDENCE_PATH/$TRACE_NAME-xctrace.log" 2>&1 &
    TRACE_PROCESS_ID=$!

    # Instruments needs a moment to attach its data collectors to the booted
    # simulator. Five seconds is intentionally boring and easy to understand.
    sleep 5
}

finish_trace() {
    TRACE_NAME="$1"

    if ! wait "$TRACE_PROCESS_ID"; then
        echo "TRACE_FAILED=$TRACE_NAME"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        return
    fi

    # A table-of-contents XML file is small enough to commit to Git. It proves
    # which Instruments tables were captured without committing a huge binary
    # .trace package to the project repository.
    if ! xcrun xctrace export \
        --quiet \
        --input "$EVIDENCE_PATH/$TRACE_NAME.trace" \
        --toc \
        --output "$EVIDENCE_PATH/$TRACE_NAME-toc.xml" \
        >"$EVIDENCE_PATH/$TRACE_NAME-export.log" 2>&1; then
        echo "TRACE_EXPORT_FAILED=$TRACE_NAME"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        return
    fi

    echo "TRACE_FINISHED=$TRACE_NAME"
}

# 1. Launch: Time Profiler starts before the deterministic fixture app. The
# trace therefore contains the complete CoreSimulator launch and first frame.
record_host_trace "Time Profiler" "Launch" "20s"
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
if ! xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" --ui-testing \
    >"$EVIDENCE_PATH/Launch.log" 2>&1; then
    echo "EXERCISE_FAILED=Launch"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi
finish_trace "Launch"

# 2. Scrolling: Time Profiler watches the CoreSimulator processes while
# XCUITest performs the same repeatable fast swipes used by the signpost test.
record_host_trace "Time Profiler" "Scrolling" "75s"
if ! xcodebuild test \
    -quiet \
    -project "News App.xcodeproj" \
    -scheme "News App" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$EVIDENCE_PATH/ScrollingTest.xcresult" \
    '-only-testing:News AppUITests/NewsPerformanceUITests/testScrollingPerformance' \
    >"$EVIDENCE_PATH/ScrollingTest.log" 2>&1; then
    echo "EXERCISE_FAILED=Scrolling"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi
finish_trace "Scrolling"

# 3. Networking: launch the real (non-fixture) build while Network records all
# simulator traffic. The repository contains no real API secret, so a 401 from
# the placeholder token is expected; the purpose here is to inspect request
# timing and confirm the app handles the server response without crashing.
record_host_trace "Network" "Networking" "25s"
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
if ! xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" \
    >"$EVIDENCE_PATH/NetworkingLaunch.log" 2>&1; then
    echo "EXERCISE_FAILED=Networking"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi
finish_trace "Networking"

# 4. Memory: first run the complete search/detail/bookmark journey. Then launch
# the fixture once more and ask Apple's leaks and vmmap tools to inspect that
# exact iOS process. These command-line tools use the same simulator analysis
# support as Instruments and produce small, reviewable text evidence.
if ! xcodebuild test \
    -quiet \
    -project "News App.xcodeproj" \
    -scheme "News App" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$EVIDENCE_PATH/MemoryJourney.xcresult" \
    '-only-testing:News AppUITests/CriticalUserJourneysUITests/testSearchOpenAndBookmarkStory' \
    >"$EVIDENCE_PATH/MemoryJourney.log" 2>&1; then
    echo "EXERCISE_FAILED=Memory"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi

APP_LAUNCH_OUTPUT=$(xcrun simctl launch \
    --terminate-running-process \
    "$SIMULATOR_ID" \
    "$BUNDLE_ID" \
    --ui-testing)
APP_PROCESS_ID=${APP_LAUNCH_OUTPUT##*: }
echo "APP_PROCESS_ID=$APP_PROCESS_ID" >"$EVIDENCE_PATH/MemoryProcess.log"
sleep 4

if ! /usr/bin/leaks "$APP_PROCESS_ID" \
    >"$EVIDENCE_PATH/MemoryLeaks.txt" 2>&1; then
    echo "EXERCISE_FAILED=MemoryLeaks"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi

if ! /usr/bin/vmmap -summary "$APP_PROCESS_ID" \
    >"$EVIDENCE_PATH/MemoryMap.txt" 2>&1; then
    echo "EXERCISE_FAILED=MemoryMap"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
fi

echo "MEMORY_ANALYSIS_FINISHED=$APP_PROCESS_ID"

echo "EVIDENCE_PATH=$EVIDENCE_PATH"
echo "FAILURE_COUNT=$FAILURE_COUNT"

if [ "$FAILURE_COUNT" -ne 0 ]; then
    exit 1
fi
