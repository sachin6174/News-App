#!/usr/bin/env node
/**
 * Minimal App Store Connect API client, enough to attach a build to a version
 * and submit that version for review.
 *
 * The UI route for this is hover-revealed controls on slow-loading pages, which
 * did not automate reliably. The API does the same work deterministically.
 *
 * Runs on the Mac, where the .p8 private key already lives — the key is read
 * locally and never leaves the machine.
 *
 * Usage:
 *   node asc-api.js status                 # read-only: version, build, state
 *   node asc-api.js attach <buildVersion>  # point the version at that build
 *   node asc-api.js submit                 # submit the version for review
 */

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const KEY_ID = process.env.ASC_KEY_ID || '7V2V2Y7758';
const ISSUER_ID = process.env.ASC_ISSUER_ID;
const APP_ID = process.env.ASC_APP_ID || '6810530638';
const VERSION_STRING = process.env.ASC_VERSION || '1.0';
const KEY_PATH = path.join(os.homedir(), '.appstoreconnect', 'private_keys', `AuthKey_${KEY_ID}.p8`);

if (!ISSUER_ID) {
    console.error('ASC_ISSUER_ID is not set.');
    process.exit(1);
}

function base64url(input) {
    return Buffer.from(input).toString('base64')
        .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

/** ES256 JWT, per Apple's App Store Connect API auth requirements. */
function token() {
    const header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const payload = {
        iss: ISSUER_ID,
        iat: now,
        exp: now + 15 * 60, // Apple rejects anything longer than 20 minutes.
        aud: 'appstoreconnect-v1',
    };
    const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
    const key = fs.readFileSync(KEY_PATH, 'utf8');
    const der = crypto.sign('sha256', Buffer.from(signingInput), {
        key, dsaEncoding: 'ieee-p1363', // JWS wants raw r||s, not DER.
    });
    return `${signingInput}.${base64url(der)}`;
}

async function api(method, endpoint, body) {
    const url = endpoint.startsWith('http')
        ? endpoint
        : `https://api.appstoreconnect.apple.com${endpoint}`;
    const res = await fetch(url, {
        method,
        headers: {
            Authorization: `Bearer ${token()}`,
            'Content-Type': 'application/json',
        },
        body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON error body */ }
    if (!res.ok) {
        const detail = json?.errors?.map((e) => `${e.title}: ${e.detail}`).join(' | ') || text.slice(0, 500);
        throw new Error(`${method} ${endpoint} -> ${res.status}\n  ${detail}`);
    }
    return json;
}

/** The editable version record for VERSION_STRING. */
async function findVersion() {
    const r = await api('GET',
        `/v1/apps/${APP_ID}/appStoreVersions?filter[versionString]=${VERSION_STRING}&limit=5`);
    const v = r.data?.[0];
    if (!v) throw new Error(`no appStoreVersion found for ${VERSION_STRING}`);
    return v;
}

async function findBuild(buildVersion) {
    const r = await api('GET',
        `/v1/builds?filter[app]=${APP_ID}&filter[version]=${encodeURIComponent(buildVersion)}&limit=5`);
    const b = r.data?.[0];
    if (!b) throw new Error(`no build ${buildVersion} found for app ${APP_ID}`);
    return b;
}

async function status() {
    const version = await findVersion();
    console.log(`version ${VERSION_STRING}`);
    console.log(`  id:    ${version.id}`);
    console.log(`  state: ${version.attributes.appStoreState || version.attributes.appVersionState}`);

    const builds = await api('GET', `/v1/builds?filter[app]=${APP_ID}&limit=10&sort=-uploadedDate`);
    console.log('builds (newest first):');
    for (const b of builds.data || []) {
        console.log(`  ${b.attributes.version.padEnd(12)} ${b.attributes.processingState.padEnd(10)} ${b.attributes.uploadedDate}`);
    }

    const attached = await api('GET', `/v1/appStoreVersions/${version.id}/build`).catch(() => null);
    console.log(`attached build: ${attached?.data?.attributes?.version ?? '(none)'}`);
    return version;
}

async function attach(buildVersion) {
    const version = await findVersion();
    const build = await findBuild(buildVersion);
    console.log(`attaching build ${build.attributes.version} (${build.id}) to version ${version.id}`);
    await api('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, {
        data: { type: 'builds', id: build.id },
    });
    const now = await api('GET', `/v1/appStoreVersions/${version.id}/build`);
    console.log(`attached build is now: ${now.data?.attributes?.version}`);
}

/**
 * Submits through the reviewSubmissions flow. The older
 * appStoreVersionSubmissions endpoint now refuses CREATE — Apple only accepts
 * DELETE there — so this creates (or reuses) a review submission, adds the
 * version to it as an item, and then marks the submission submitted.
 */
async function submit() {
    const version = await findVersion();

    // Reuse an open submission if one is already sitting there unsent.
    const existing = await api('GET',
        `/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES&limit=10`)
        .catch(() => null);
    let submission = existing?.data?.find((s) => !s.attributes.submitted);

    if (submission) {
        console.log(`reusing open review submission ${submission.id} (state ${submission.attributes.state})`);
    } else {
        const created = await api('POST', '/v1/reviewSubmissions', {
            data: {
                type: 'reviewSubmissions',
                attributes: { platform: 'IOS' },
                relationships: { app: { data: { type: 'apps', id: APP_ID } } },
            },
        });
        submission = created.data;
        console.log(`created review submission ${submission.id}`);
    }

    const items = await api('GET', `/v1/reviewSubmissions/${submission.id}/items?limit=20`)
        .catch(() => ({ data: [] }));
    const alreadyAdded = (items.data || []).some(
        (i) => i.relationships?.appStoreVersion?.data?.id === version.id);

    if (alreadyAdded) {
        console.log('version is already an item on this submission');
    } else {
        await api('POST', '/v1/reviewSubmissionItems', {
            data: {
                type: 'reviewSubmissionItems',
                relationships: {
                    reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
                    appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
                },
            },
        });
        console.log(`added version ${VERSION_STRING} to the submission`);
    }

    console.log('submitting...');
    const done = await api('PATCH', `/v1/reviewSubmissions/${submission.id}`, {
        data: { type: 'reviewSubmissions', id: submission.id, attributes: { submitted: true } },
    });
    console.log('submission state:', done.data?.attributes?.state);
    console.log('submitted flag:', done.data?.attributes?.submitted);

    const after = await findVersion();
    console.log('version state now:', after.attributes.appStoreState || after.attributes.appVersionState);
}

/** Reports the required fields Apple checks before a version can be reviewed. */
async function check() {
    const version = await findVersion();
    console.log(`version state: ${version.attributes.appStoreState || version.attributes.appVersionState}`);

    const appInfos = await api('GET', `/v1/apps/${APP_ID}/appInfos?limit=5`);
    for (const info of appInfos.data || []) {
        console.log(`appInfo ${info.id} state=${info.attributes.appStoreState || info.attributes.state}`);
        const locs = await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations?limit=10`);
        for (const l of locs.data || []) {
            const a = l.attributes;
            console.log(`  [${a.locale}] name="${a.name}" subtitle="${a.subtitle ?? ''}"`);
            console.log(`      privacyPolicyUrl: ${a.privacyPolicyUrl ?? '(EMPTY)'}`);
            console.log(`      localizationId:   ${l.id}`);
        }
        const cats = await api('GET', `/v1/appInfos/${info.id}?include=primaryCategory,secondaryCategory`);
        const inc = (cats.included || []).map((c) => c.id).join(', ');
        console.log(`  categories: ${inc || '(none)'}`);
    }

    const vlocs = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=10`);
    for (const l of vlocs.data || []) {
        const a = l.attributes;
        console.log(`version loc [${a.locale}] id=${l.id}`);
        console.log(`  description: ${a.description ? `${a.description.length} chars` : '(EMPTY)'}`);
        console.log(`  keywords:    ${a.keywords ? `${a.keywords.length} chars` : '(EMPTY)'}`);
        console.log(`  supportUrl:  ${a.supportUrl ?? '(EMPTY)'}`);
        const sets = await api('GET', `/v1/appStoreVersionLocalizations/${l.id}/appScreenshotSets?limit=20`);
        for (const s of sets.data || []) {
            const shots = await api('GET', `/v1/appScreenshotSets/${s.id}/appScreenshots?limit=20`).catch(() => null);
            console.log(`  screenshots ${s.attributes.screenshotDisplayType}: ${shots?.data?.length ?? '?'}`);
        }
    }
}

/** The gates that commonly block a version: build compliance, age rating, pricing. */
async function gates() {
    const build = await findBuild(process.env.ASC_BUILD || '1');
    console.log('build', build.attributes.version);
    console.log(`  processingState:       ${build.attributes.processingState}`);
    console.log(`  usesNonExemptEncryption: ${build.attributes.usesNonExemptEncryption}`);
    console.log(`  buildId: ${build.id}`);

    const version = await findVersion();
    const detail = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`).catch((e) => ({ err: e.message }));
    console.log('appStoreReviewDetail:', detail.err ? detail.err.split('\n')[0] : JSON.stringify(detail.data?.attributes));

    const ageRating = await api('GET', `/v1/appInfos?filter[app]=${APP_ID}&include=ageRatingDeclaration`).catch((e) => ({ err: e.message }));
    if (ageRating.err) console.log('ageRating:', ageRating.err.split('\n')[0]);
    else console.log('ageRatingDeclaration present:', Boolean((ageRating.included || []).find((i) => i.type === 'ageRatingDeclarations')));

    const prices = await api('GET', `/v1/apps/${APP_ID}/appPriceSchedule`).catch((e) => ({ err: e.message }));
    console.log('priceSchedule:', prices.err ? prices.err.split('\n')[0] : 'set');
}

/** Answers the export-compliance question on a build. */
async function setCompliance(buildVersion, usesNonExempt) {
    const build = await findBuild(buildVersion);
    await api('PATCH', `/v1/builds/${build.id}`, {
        data: { type: 'builds', id: build.id, attributes: { usesNonExemptEncryption: usesNonExempt } },
    });
    const after = await findBuild(buildVersion);
    console.log(`usesNonExemptEncryption is now: ${after.attributes.usesNonExemptEncryption}`);
}

/** Sets the privacy policy URL on every app info localization. */
async function setPrivacy(url) {
    const appInfos = await api('GET', `/v1/apps/${APP_ID}/appInfos?limit=5`);
    for (const info of appInfos.data || []) {
        const locs = await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations?limit=10`);
        for (const l of locs.data || []) {
            await api('PATCH', `/v1/appInfoLocalizations/${l.id}`, {
                data: { type: 'appInfoLocalizations', id: l.id, attributes: { privacyPolicyUrl: url } },
            }).then(() => console.log(`set privacyPolicyUrl on ${l.attributes.locale}`))
              .catch((e) => console.log(`failed on ${l.attributes.locale}: ${e.message.split('\n')[1] || e.message}`));
        }
    }
}

/** Dumps every review submission and its items, so a stuck one can be understood. */
async function inspect() {
    const subs = await api('GET', `/v1/apps/${APP_ID}/reviewSubmissions?limit=20`);
    for (const s of subs.data || []) {
        console.log(`submission ${s.id}`);
        console.log(`  state:     ${s.attributes.state}`);
        console.log(`  submitted: ${s.attributes.submitted}`);
        console.log(`  platform:  ${s.attributes.platform}`);
        const items = await api('GET', `/v1/reviewSubmissions/${s.id}/items?limit=20`).catch(() => null);
        for (const it of items?.data || []) {
            const rel = it.relationships || {};
            const kind = Object.keys(rel).find((k) => rel[k]?.data) || 'unknown';
            console.log(`  item ${it.id} state=${it.attributes?.state} -> ${kind}:${rel[kind]?.data?.id}`);
        }
    }
}

/** Cancels a review submission (or removes its items) so a fresh one can be made. */
async function cancel(submissionId) {
    const items = await api('GET', `/v1/reviewSubmissions/${submissionId}/items?limit=20`).catch(() => null);
    for (const it of items?.data || []) {
        // REMOVED is how an item is withdrawn from a submission still in flight.
        await api('PATCH', `/v1/reviewSubmissionItems/${it.id}`, {
            data: { type: 'reviewSubmissionItems', id: it.id, attributes: { removed: true } },
        }).then(() => console.log(`removed item ${it.id}`))
          .catch((e) => console.log(`could not remove item ${it.id}: ${e.message.split('\n')[1] || e.message}`));
    }
    await api('DELETE', `/v1/reviewSubmissions/${submissionId}`)
        .then(() => console.log(`deleted submission ${submissionId}`))
        .catch((e) => console.log(`could not delete submission: ${e.message.split('\n')[1] || e.message}`));
}

const [cmd, arg] = process.argv.slice(2);
(async () => {
    if (cmd === 'status') await status();
    else if (cmd === 'attach') await attach(arg || '1');
    else if (cmd === 'submit') await submit();
    else if (cmd === 'inspect') await inspect();
    else if (cmd === 'cancel') await cancel(arg);
    else if (cmd === 'check') await check();
    else if (cmd === 'gates') await gates();
    else if (cmd === 'set-compliance') await setCompliance(arg || '1', false);
    else if (cmd === 'set-privacy') await setPrivacy(arg);
    else {
        console.error('usage: asc-api.js status|check|inspect|attach <buildVersion>|set-privacy <url>|cancel <id>|submit');
        process.exit(1);
    }
})().catch((e) => { console.error('ERROR:', e.message); process.exit(1); });
