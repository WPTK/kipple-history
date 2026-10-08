# Owner feedback, 2026-10-03 evening to 2026-10-07

His own words where short; anything about hosts, people or named apps is paraphrased. Days are Eastern time (the source
timestamps are UTC, so a message sent after 8 pm Eastern is filed under that evening). Routine "yes", "go" and
"proceed" are left out unless they authorized something. Rulings that are already recorded are linked, not repeated:
[DECISIONS.md](../DECISIONS.md), [the diaries](../diary/), [research/marketing-and-launch-2026-10-05.md](../research/marketing-and-launch-2026-10-05.md).

He wrote mostly from a phone or between sessions, with up to four or five sessions open at once on 2026-10-06, and wanted
short answers that lead with the result.

## 2026-10-03 (evening)

**Release words**
- "Yes tag it." Then, after I made a pre-release: "And so I said release, and you did pre-release anyway." He had said
  "release" because the last full release was 0.2.0 and a lot had happened since. "Release" means a full release. When I asked
  whether that should become the rule: "No. Just this one." Recorded in [DECISIONS.md](../DECISIONS.md) (2026-10-04: 0.8.0-beta.1
  is a full release).

**Product decisions**
- Podcasts: "Kipple will not support podcasts. That is simply not in scope. I'm not looking to just have what everyone else
  has." Read-later is intentionally absent. A per-reader migration guide is not needed: "People can figure it out themselves."
- Stars and read state from other readers: he did not think they came across, "but if they do, we need to figure it out."
- The nested-folder problem is a fix to make.

**Process and cost rules**
- Asked for deep pre-1.0 research: "Commit some time and energy to this. No skimming." Not only his five links; find other
  reputable sources and discuss them at the final meeting. A scrubbed copy went into the history repo, which he approved when I
  asked ([research/](../research/), the five pre-1.0 reports).
- The plan to 1.0 was to be drawn up by me, with me able to work, merge and commit PRs that need no review of his, with
  kipple-history and website updates as normal workflow, "mostly without human intervention, at least for the next 12-16
  hours." Also: apply the tips for the "we're overdoing it" problem, but weigh what the earlier effort taught. See
  [plans/0.8-1.0-plan.md](../plans/0.8-1.0-plan.md).

**Behaviour and testing**
- The blur in the installed app "only happens in the PWA now", on iOS 27, and "it's added to my home screen that's what a PWA
  is" (I had asked whether he meant the browser). Later: "it is 100% a bug on their side not ours" (WebKit, dropped).
- He gave permission to start a local test page: it exposes nothing, the machine is on the private network. Then "Close the
  test server."
- Going to sleep: "Keep working at it."

## 2026-10-04

**Morning meeting answers** (recorded in [DECISIONS.md](../DECISIONS.md), 2026-10-04)
- Five numbered answers: keep, fine, fine, the iOS 27 blur is a platform bug, and "Yes, tag it as a full release. Deploy
  after."

**README and docs direction**
- The README copy "is a little AI slop ish"; the description needs a human-style rewrite. Remove from the non-features list:
  no read-later service, the line saying you cannot share (you can, through the share sheet), "no Fever API" ("No one
  cares"). "No monitoring or analytics" needs an asterisk for the self-hosted stats feature. And there was no list of what
  Kipple does, only what it does not. These became issues, with a docs-only audit later.
- A sentence about how prerelease images are tagged with their exact version, and where backups and proxy notes are: "Literally
  no one needs to know that. Remove that and stuff like that." Added to the docs review.

**Product direction he asked me to track**
- An issue for moving backup and restore from the command line into the app, then a broader one for moving every
  command-line-only feature into the UI: "I just need you to track that I want to work on that." (#246, #247)

**Process and cost rules**
- "This seems like it's taking way too long, what's the status?" during a release step.
- A second session, started for an optimisation audit, was told to finish every recommendation after its agents finished and
  report the savings (time, lines, size). He then asked what had been declined, said "Dive deeper and start work," and:
  "Run the code review and CI and all that. Get it to the point where you ask me to merge."
- "Is a Fable code review worth the tokens?" then "I want you to find more opportunities for narrow Opus reviews and run those too."
- Merge, then tag and deploy, were each said in chat; "Go ahead and merge and tag this one time" covered one PR.

## 2026-10-05

**Issue review meeting rulings** (in [DECISIONS.md](../DECISIONS.md), 2026-10-05 and later entries)
- Docs issues batched into their own milestone. Fix #241 now; #244 export matches web order, documented; #229 lower the scan
  limit to about 75,000 documents; close #33; check #179 and close it if done; #236 waits for the roadmap agenda.
- Beta.2 stays perf only, then beta.3. Later: "I haven't used beta.2 at all, so we can just go ahead and roll with testing beta.3."
- The search cap: "I may not understand this search limit cap. Tell me what's going on. Everything I suggest keeps sounding
  like you're telling me it's the wrong answer." The ruling was recorded after a plain explanation.
- "Always code review high", later widened to every PR before merge.
- Open mode should not assume one private-network tool: "someone might use something other than" it, "so I'd like for this to be
  more open." (#254, PR #259)
- Soak: "only needs to be like 24 hours, because it is heavily used."
- Issues past milestone 5 stay open; milestone 5 closes. Worktree cleanup was left to me; junk deleted; stale docs go to the
  history repo "in the right area"; the history repo "brought up to date" and the pre-rewrite copy deleted.

**Corrections to my behaviour**
- Named reader apps: "we have got to stop referencing" them. It is any RSS reader client on any system; nothing should be
  built for one app. He proposed a milestone that guarantees compatibility with any reader (#256). Memory rule added.
- Agenda: it was "a little disconnected since different agents reported at different times". He asked for one agenda.
- Decisions: asked for all outstanding decisions in one place, twice, and for a recommended action on each.
- Cleanup commands: he did not run a destructive command I had told him to skip if unsure, and gave me the output of the rest.
  I gave exact commands for him to run instead.
- "What the hell is a 'production read'. That's just a read. It's nondestructive." I had held back on reading the Kipple
  server's settings. Then: "Give me the exact command and I'll do it." Later, after he had run it: "I keep running it, you keep
  telling me it's not been run. I think you're giving me the wrong command."
- "I shouldn't have any envs, I thought we were moving to settings in GUI?" Reachability settings move into setup and Settings
  (#265).

**Product decisions**
- All Reader API clients collapse into one generic `api` value, with a migration (#267).
- Compatibility problems are fixed now, not later: "If it's a computability issue, it needs to be resolved now." (#256, #266)
- Adding a feed must go as smoothly as possible, including fetching the title (#255).
- Issues for the link checker and the weekly check; a signature file ("sig file - yes, I care"); zizmor as a gate ("I thought we
  had that already", #252). An issue for the continuity paragraph: it must say the project is vibe coded, and that "I'm just
  really good at talking to robots." (#269, the "How Kipple is made" README section: "write it, let me see a draft. No slop.
  Follow the skills.")
- #265 and #236 before 1.0, in this beta; #38 now.
- #207 split: #39, then #37 with #36, and #246 each get their own session and a prompt to continue elsewhere; #35 stays in the
  parking lot; #34 becomes "Post 1.0" rather than "2.0.0".
- Evening: "beta.3 can be pre-release." "No, don't ask again, just do it. I am away from my machine for a while." (This release
  only, per DECISIONS.md.) Beta.3 had to go through UAT first.

**Marketing meeting** ([research](../research/marketing-and-launch-2026-10-05.md))
- Brief: free, not just social media and Discord, not just asking friends. He put "marketing" in quotes: "I'm not saying I'm
  going to monetize it." He asked whether a more open license would help (the license stayed).
- Launch at 1.0; be clear it is also an experiment in working with coding agents; the demo comes later; "this is just planning
  though": document it in the history repo, scrubbed and marked as a meeting.

**Process and cost rules**
- Two public repo-hygiene lists, then five more articles: "Don't actually do anything yet. Just review." And: "Coming back with
  nothing is okay -- you don't have to make up something."
- A second session had two PRs open; he asked me to take over the one I had not started: "I'd rather do it all in one session."
- Permission rules: give him the rule to add and a breakdown of the classifier and other suggested additions; later "I think I
  added the permission rules, try again."
- A sidebar about what else belongs in `.gitignore`.

**Late evening** (after 11 pm and past midnight)
- "Is there a benefit to implementing Haiku into our workflow? I know I say no to it currently." He asked if anything could
  step down; the standing rule is unchanged (never Haiku).
- Liked the release-gates idea and asked for more like it; asked me to create the tooling issues serially. His condition: the
  scripts should not reach end users, "the scrub script will have my data in it", so owner-specific terms stay in an untracked
  file. "I don't want my information leaked. I don't want poorly scripted PowerShell." And: "These need to be repairable for the
  future too. Please remember that." (memory: tooling must be repairable)
- Asked whether squash merging would save tokens, asked for other savings, then picked which to implement. "I like the batch
  small PRs", kept for non-docs work.
- "I'm heading to bed. I want a full summary and projected/estimated savings to review when I wake up, along with decisions."
- Unused connectors off, "Except for ones needed for UI testing."
- He planned three to five new sessions and asked how they could coordinate so he would not have to referee them. See
  [DECISIONS.md](../DECISIONS.md) (2026-10-06, working economy and session coordination).

## 2026-10-06

**Morning**
- A command I had named was not in the repo; he wanted the summary shown in chat for the meeting, then: "Double check that
  command ran safely, before we continue."
- "I believe I've run all the commands you need. If not, just execute them, this one time. You run the deploy helper, not me."
  On another item: "you do what you think is right". Then: "Update kipple-history."

**Gazette layout session** (design only; see [plans/gazette-layout.md](../plans/gazette-layout.md))
- He wanted more creative options than his rough first ideas: research styles in other readers and sites. "One I just thought of
  is to design it like a newspaper, a big headline + articles so it looks literally like a newspaper." The email-client style
  layouts should look more like the real thing, without naming the product. New layouts get the compact toggle, with a mobile version.
- After four mockups: "Okay, i LOVE the newspaper layout." No lead photo means a bigger headline; the front page should
  reconfigure around the content, "just like a real newspaper isn't the exact same layout every day." Daily edition: drop it
  for now. Triage stack: loved. Source rows: good. "For these layouts I don't particularly care if it meets the contract."
- The lead is the newest article with an image from a feed (or folder) the reader pins. Pins reuse favorites.
- Later: more than three page layouts; inner pages should look like a real page 2, 3, 4; name it "The Gazette", renameable in
  Settings; remove the pinned icon, "it kills the vibe". Sections by folder or feed name, a finite paper, seven page types.
  Very wide dropped; pieces fade in place. "Scope it. I want this to be ready to build when we say go." And: "Shouldn't it go
  into the issue and the history repo?"

**Stats session** (#37, #36; [DECISIONS.md](../DECISIONS.md))
- Screen design: recommendation A, promote the drill-down if the sheet outgrows it. #36: could it simply say that stats cannot
  be accurate when reading in another app? It was closed as not planned. He questioned why a PR was "docs only".
- Compare toggle default off, and the first interaction was "a bit of AI Slop"; he wanted percents, with counts on tap, and
  per-feed deltas. Asked for mockups before building. "I have like four other sessions going, so keep that in mind."

**Backup and restore session** (#246, #283; [DECISIONS.md](../DECISIONS.md), 2026-10-06 evening)
- He began with the purpose: "What are we trying to accomplish? ... Is it really needed?" Then: restore into a fresh install,
  as part of setup, optionally with the OPML.
- "Does the user care about the schema? That's internal to me and you." No schema numbers outside the About page. A bare OPML
  file must still be accepted, with helper text. The CLI command may stay "SO LONG AS there is a GUI way".
- On risks: a process that exists only in the CLI "is against the guidance I've given"; reset must say what it does and offer to
  clear the environment variables behind an "are you sure" warning; races and the restart problem to be solved; a progress
  indicator or time estimate for long restores. "Build it now. This needs to go in to the next build/release. You decide what
  that is." Later: "Start #283 now."

**Other reports**
- The sidebar font changed when the reader font changed; it should stay the default, with an optional setting (default off).
  "Open the PR and go", then "Run the code review, then merge."

**README rewrite** (PR #291)
- "It looks kinda like slop." The quote about kipple from the book was weak; find better ones. Compare to READMEs of real
  readers and open source apps. He listed sources and asked for primary, non-generated ones.
- Rulings: keep the important badges, drop the hits counter; add screenshots with their own workflow (different from the
  website's); remove duplicated content; move install detail to deploy and note the intended flow, "a person pulls the image,
  browses to the setup, and begins"; drop the version everywhere; remove the releasing section and question whether that file
  should be public; drop Support and For developers; "concrete phrases only"; the epigraph second, styled as a quote with the
  book credited.
- Review of the first draft: "Those first two screenshots look like shit." and "Why are you making it difficult for me to see?"
  (show the README in chat). Then: reword the sync-API phrase; italicise the quote and the stats note; explain layouts rather
  than naming them; screenshots "half bare" and the phone one off-centre, with captions saying web or mobile; split things that
  did not belong together (nested folders with import and export); cut full-text extraction, shorten the retention and sync
  lines, generalise backup and restore, "just say it's designed for a single user environment", native podcast or video players
  only (a link still works), and the social line should say you can still share from the web app with the device share sheet.
  He asked whether the rules claim was true ("Is this true? Are there rules?"). "Push it." "Just merge. It's fine." Terms to be
  genericised everywhere, tracked as an issue (#298).
- He asked me to save how we structured the wording to memory.

**Coordination and release**
- After several sessions: "What's the attack plan to implement these and get them in?" "Start where you need to start." On a PR
  owned by another session: "They can own it, but you need to monitor it for me."
- "Yes, tag, release and deploy beta.4." (evening; PR #293)
- End of day: review every session in depth, bring decisions, make the plan, "Provide enough work to continue without needing
  me." Answers: review after the high review; stats and the Gazette "earlier, I want them in either the next beta or 0.9.0";
  notify the user about the reset change; auto-compact at 300K tokens. Then a prompt for a new session to start beta.5.

## 2026-10-07

Rulings are in [DECISIONS.md](../DECISIONS.md) (2026-10-07). His words:

- **Stats periods:** exclude today from both periods. (Recommended option chosen.)
- **Offline relaunch (#253):** keep it in 1.0.
- **Reset:** a notice only, no one-time setup secret. (Recommended option chosen.)
- **Release:** "Tag, release and deploy. Do whatever else you need to do." Then: "Don't forget the website and the history."
  (beta.5)
- **The new filter editor on a phone:** "Why can't tap these words?" Then: "I have never made a filter prior to this. There is
  no other filter. I did not tap those to add." The words had been added for them.
- **The ruling:** "that behavior sucks (the pre filling with the first three words). Super common words need to be excluded,
  too." On the proposed shape (start empty, toggling chips, a bigger stop list): "Fix based on your recs." Recorded as a
  default the reader did not choose being removed rather than explained.
- **Recurring rule, reinforced:** every review finding is fixed, none skipped.
- **History:** "Any gaps in kipple history we need to fill in today or yesterday or this week? Take some time and do that.
  Be thorough."
