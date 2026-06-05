#!/usr/bin/env node
// Static contract for the TopicDetailPage State Management V1 -> V2 split lane.
//
// The whole-file purity of TopicDetailPage.ets is already asserted by
// test_v2_leaf_migration_contract.mjs (it is registered in v2-migrated-leaves.json). THIS check
// pins the lane-specific wiring that the leaf contract cannot see, and fails closed if a future
// edit silently regresses any of it:
//
//   1. TopicDetailPage consumes the V2 backbone correctly: connectNavStack().stack (no @Consume),
//      the three reactive mirrors (auth-cookie / motion-edge / reply-button), and @Monitor for the
//      motion-edge + reply-button preferences.
//   2. TOPIC_DETAIL_ACTION is observed directly by TopicDetailPage via the V2 TopicDetailActionState
//      mirror (@Monitor); the former V1 TopicDetailActionListener child adapter was retired when
//      Index migrated to @ComponentV2.
//   3. The three mirror dual-write chokepoints exist at their single writers.
//   4. Index.ets does not import TopicDetailPage's private reactive-reading mirrors; only the
//      cross-page command/appbar mirrors (TOPIC_DETAIL_ACTION, appbar identity) are shared.
//
// Run: node scripts/test_topicdetail_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const read = (rel) => readFileSync(join(repo, rel), 'utf8');
// strip comments so prose mentioning a decorator/token never trips a check
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

let failures = 0;
const ok = (m) => console.log(`ok   ${m}`);
const fail = (m) => { console.error(`FAIL ${m}`); failures++; };
const must = (cond, m) => (cond ? ok(m) : fail(m));

const PAGE = 'feature/detail/src/main/ets/pages/TopicDetailPage.ets';
const ACTION_MIRROR = 'shared/src/main/ets/state/TopicDetailActionState.ets';
const INDEX = 'entry/src/main/ets/pages/Index.ets';

// 1) TopicDetailPage V2 backbone wiring -------------------------------------------------------
{
  const raw = read(PAGE);
  const code = strip(raw);
  must(/@ComponentV2\b/.test(code), `${PAGE}: is @ComponentV2`);
  must(/connectNavStack\(\)\.stack/.test(code), `${PAGE}: navigation via connectNavStack().stack`);
  must(/connectAuthCookie\(\)/.test(code), `${PAGE}: reads connectAuthCookie() mirror`);
  must(/connectMotionHandEdge\(\)/.test(code), `${PAGE}: reads connectMotionHandEdge() mirror`);
  must(/connectTopicDetailReplyButton\(\)/.test(code), `${PAGE}: reads connectTopicDetailReplyButton() mirror`);
  must(/@Monitor\(\s*['"]motion\.edge['"]\s*\)/.test(code), `${PAGE}: @Monitor('motion.edge')`);
  must(/@Monitor\(\s*['"]replyButton\.autoHide['"]\s*\)/.test(code), `${PAGE}: @Monitor('replyButton.autoHide')`);
  // command bus is observed directly via the V2 TopicDetailActionState mirror (the former V1
  // TopicDetailActionListener child adapter was retired once Index migrated to @ComponentV2).
  must(/connectTopicDetailAction\(\)/.test(code) && /@Monitor\(\s*['"]topicAction\.command['"]\s*\)/.test(code),
    `${PAGE}: observes TOPIC_DETAIL_ACTION via the mirror @Monitor (no V1 listener child)`);
  must(!/TopicDetailActionListener/.test(code), `${PAGE}: no longer hosts the retired TopicDetailActionListener`);
  must(/command\.topicId !== this\.topicId/.test(code), `${PAGE}: filters the command bus by its own topicId (no stacked-page double-fire)`);
  // appbar identity behavior preserved (same coordinator + route-id key publishing)
  must(/TopicDetailAppbarCoordinator/.test(code), `${PAGE}: still uses TopicDetailAppbarCoordinator`);
  // State Management V2 migration: the route-id (and the rest of the appbar identity) is now published
  // via the TopicDetailAppbarState write-through helpers (V1 key + V2 mirror the @ComponentV2 Index reads).
  must(/publishTopicDetailAppbarRouteTopicId\(/.test(code) || /StorageKeys\.TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID/.test(code), `${PAGE}: publishes appbar route-id key`);
  // no V1 component-state decorators survive (defense-in-depth vs leaf contract)
  for (const d of ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink', '@CustomDialog']) {
    must(!new RegExp(`${d}\\b`).test(code), `${PAGE}: no surviving ${d}`);
  }
}

// 1b) Resume-reading affordance: entry no longer auto-scrolls to the saved floor; instead it
//     surfaces a button that performs the jump on tap and is consumed (hidden) afterwards. -----------
{
  const code = strip(read(PAGE));
  must(/@Local\s+private\s+showResumeButton\s*:\s*boolean/.test(code),
    `${PAGE}: declares @Local showResumeButton flag`);
  // restoreReadPosition surfaces the button instead of scrolling on entry
  must(/this\.showResumeButton\s*=\s*true/.test(code),
    `${PAGE}: restoreReadPosition shows the resume button (no auto-scroll on entry)`);
  // the tap handler jumps to the floor and consumes the affordance
  must(/resumeToSavedFloor\(\)/.test(code) && /this\.showResumeButton\s*=\s*false/.test(code),
    `${PAGE}: tap jumps to the saved floor and consumes (hides) the resume button`);
  // scrolling the saved floor into view auto-dismisses the button
  must(/maybeDismissResumeButton\(/.test(code),
    `${PAGE}: scroll-into-view auto-dismisses the resume button`);
  // accessibility text for the button is an i18n resource (not a hardcoded string)
  must(/R_TOPIC_ACTION_RESUME_READING/.test(code),
    `${PAGE}: resume button uses the i18n accessibility resource`);
}

// 1c) Floating reply/resume buttons must stay above foldable outer-screen bottom protection.
//     Some devices report little/no navigation-indicator inset on the outer screen; the FAB still
//     needs its own visual clearance and the HDS internal bottom margin must match the activity box.
{
  const raw = read(PAGE);
  const code = strip(raw);
  const coordinator = strip(read('feature/detail/src/main/ets/model/TopicDetailFloatingActionCoordinator.ets'));
  const barBottomMarginMatches = code.match(/barBottomMargin:\s*this\.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING/g) || [];
  must(/TOPIC_DETAIL_REPLY_BUTTON_BOTTOM_CLEARANCE\s*:\s*number\s*=\s*ThemeConstants\.SPACE_LG/.test(code),
    `${PAGE}: declares a minimum bottom clearance for floating reply actions`);
  must(/TopicDetailFloatingActionCoordinator\.actionBarTop\([\s\S]*this\.layout\.bottomAvoidHeight[\s\S]*this\.TOPIC_DETAIL_REPLY_BUTTON_SIZE[\s\S]*this\.TOPIC_DETAIL_REPLY_BUTTON_BOTTOM_CLEARANCE/.test(code),
    `${PAGE}: applies bottom safe area plus minimum clearance to the reply FAB`);
  must(barBottomMarginMatches.length >= 2,
    `${PAGE}: reply and resume FABs align HDS barBottomMargin with activity padding`);
  must(/bottomClearance:\s*number\s*=\s*0/.test(coordinator),
    'TopicDetailFloatingActionCoordinator.actionBarTop keeps default bottomClearance compatibility');
  must(/Math\.max\(0,\s*bottomAvoidHeight\)\s*\+\s*Math\.max\(0,\s*bottomClearance\)/.test(coordinator),
    'TopicDetailFloatingActionCoordinator.actionBarTop combines safe area and explicit clearance');
}

// 1d) Jump-to-floor uses the system CustomContentDialog chrome. The input can be custom, but the
//     title and action area must stay owned by ArkUI, not rebuilt with local Text/Row/Button layout.
{
  const code = strip(read(PAGE));
  const builderStart = code.indexOf('@Builder\n  JumpToFloorDialogContent()');
  const builderEnd = code.indexOf('\n  private handleJumpToFloor', builderStart);
  const builder = builderStart >= 0 && builderEnd > builderStart ? code.slice(builderStart, builderEnd) : '';

  must(/import\s*\{[^}]*CustomContentDialog[^}]*\}\s*from\s*['"]@kit\.ArkUI['"]/.test(code),
    `${PAGE}: imports ArkUI CustomContentDialog`);
  must(/jumpFloorDialogController\s*:\s*CustomDialogController\s*=\s*new\s+CustomDialogController\(\s*\{[\s\S]*builder:\s*CustomContentDialog\(\s*\{[\s\S]*primaryTitle:\s*AppStrings\.R_JUMP_TO_FLOOR_TITLE/.test(code),
    `${PAGE}: jump dialog is backed by CustomContentDialog title chrome`);
  must(/buttons:\s*\[[\s\S]*value:\s*AppStrings\.R_COMMON_CANCEL[\s\S]*value:\s*AppStrings\.R_JUMP_TO_FLOOR_BUTTON[\s\S]*\]/.test(code),
    `${PAGE}: jump dialog uses CustomContentDialog action buttons`);
  must(/customStyle:\s*false/.test(code),
    `${PAGE}: jump dialog keeps the system dialog container style`);
  must(/this\.jumpFloorDialogController\.open\(\)/.test(code) && /this\.jumpFloorDialogController\.close\(\)/.test(code),
    `${PAGE}: opens and closes the CustomContentDialog controller`);
  must(!/jumpFloorDialogId|openCustomDialog|closeCustomDialog/.test(code),
    `${PAGE}: no PromptAction custom dialog id path for jump dialog`);
  must(/TextInput\(\{[\s\S]*placeholder:\s*AppStrings\.R_JUMP_TO_FLOOR_PLACEHOLDER[\s\S]*text:\s*this\.jumpFloorText/.test(builder),
    `${PAGE}: jump dialog content is the floor TextInput`);
  must(/\.type\(InputType\.Number\)/.test(builder) && /\.inputFilter\(\s*['"]\^\[0-9\]\*\$['"]\s*\)/.test(builder),
    `${PAGE}: jump floor TextInput is numeric-filtered`);
  must(/normalizeJumpFloorInput\(value\)/.test(builder),
    `${PAGE}: jump floor TextInput sanitizes pasted input`);
  must(!/\b(Text|Row|Button)\(/.test(builder),
    `${PAGE}: jump dialog content does not rebuild title or action buttons`);
}

// 2) TopicDetailActionState is the V2 command-bus mirror (replaced the V1 listener adapter) ----------
{
  const code = strip(read(ACTION_MIRROR));
  must(/@ObservedV2\b/.test(code), `${ACTION_MIRROR}: @ObservedV2`);
  must(/@Trace\s+command\b/.test(code), `${ACTION_MIRROR}: @Trace command`);
  must(/export function connectTopicDetailAction\(/.test(code), `${ACTION_MIRROR}: exports connectTopicDetailAction()`);
}

// 3) Mirror dual-write chokepoints ------------------------------------------------------------
must(/connectAuthCookie\(\)\.configured\s*=/.test(strip(read('shared/src/main/ets/settings/CookieJarSettings.ets'))),
  'CookieJarSettings.refreshConfiguredState: dual-writes connectAuthCookie().configured');
must(/connectMotionHandEdge\(\)\.edge\s*=/.test(strip(read('shared/src/main/ets/services/MotionHandStateService.ets'))),
  'MotionHandStateService.setEdge: dual-writes connectMotionHandEdge().edge');
must(/connectTopicDetailReplyButton\(\)\.autoHide\s*=/.test(strip(read('shared/src/main/ets/settings/TopicDetailReplyActionSettings.ets'))),
  'TopicDetailReplyActionSettings.apply: dual-writes connectTopicDetailReplyButton().autoHide');

// 4) Index command-bus writer: writes the V2 mirror only (legacy AppStorage half retired) ---------
// (Index is now @ComponentV2 too; the former "Index-free" boundary is obsolete. The page-private
// reactive reading state — auth-cookie / motion-edge / reply-button — is still NOT imported by Index;
// only the cross-page command/appbar mirrors are.)
{
  const code = strip(read(INDEX));
  must(!/connectAuthCookie|connectMotionHandEdge|connectTopicDetailReplyButton/.test(code),
    `${INDEX}: does not import TopicDetailPage's private reactive-reading mirrors`);
  must(!/AppStorage\.(set|setOrCreate)<[^>]*>\(\s*StorageKeys\.TOPIC_DETAIL_ACTION/.test(code),
    `${INDEX}.sendTopicAction: no legacy AppStorage TOPIC_DETAIL_ACTION dual-write (V2-only)`);
  must(/connectTopicDetailAction\(\)\.command\s*=/.test(code),
    `${INDEX}.sendTopicAction: writes the V2 TopicDetailActionState mirror`);
}

console.log(`\ntopicdetail-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
