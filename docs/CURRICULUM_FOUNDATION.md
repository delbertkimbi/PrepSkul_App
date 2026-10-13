# Learner-specific curriculum context

## Implemented in this release

The app keeps country, system, class, pathway, stream, subject and exam as stable IDs in onboarding_context and sends curriculumScope to the tutor. Changing a school context clears stale subject/exam answers. Cameroon English secondary learners choose general, technical/industrial or commercial; general learners choose arts, science or mixed. These are navigation suggestions, not a verified syllabus catalogue. Specialties outside the shortlist remain available through the free-text subject.

The companion PrepSkul_Web branch codex/learner-context-retrieval accepts those IDs, includes them in the tutor context, filters harvested content by country/system/class/pathway/stream and prevents generic seed keywords from claiming curriculum alignment. On-demand lookup searches Cameroon education authority domains and retains returned source excerpts and URLs. Generated search summaries are not treated as evidence. Lookup failure leaves alignment explicitly unverified. Other countries have no authority lookup configured yet.

## Coverage and evidence

Official source discovery is not the same as verified coverage. A source needs an edition, exact class/pathway/specialty, subject and learning objective before a lesson may claim syllabus alignment. General concept explanations must remain labelled internally as unverified against the selected syllabus. Missing context that changes an answer should prompt one short clarifying question.

Sources used for the initial taxonomy:
- MINSEC anglophone education structure: https://www.minesec.gov.cm/web/index.php/en/systeme-educatif-en/offre-de-formation-en/sous-systeme-anglophone-en
- GCE Board TVEE Intermediate Level: https://camgceb.org/examinations/tve-intermediate-level/
- OpenRouter cited web lookup: https://openrouter.ai/docs/guides/features/server-tools/web-search

## Next durable content layer

Use a versioned key: country / authority / system / pathway / specialty / class / subject / exam / syllabus edition / objective / language. Filter exact metadata before semantic ranking. Store source URL, page/section, retrieved date, content hash, licensing and review state. Keep source evidence separate from model interpretations.

On a learner request: resolve scope, retrieve matching evidence, identify prerequisites and common mistakes, select one diagnostic question, generate the smallest helpful visual, then verify its labels and answer against the evidence. For Brownian motion verify random particle motion vs bulk convection; for organic chemistry verify valence and atom balance; for demand/supply distinguish shifts from movements and check labelled axes.

Reviewed reusable visuals and questions can become shared assets keyed to their objective and source version. Invalidate them when the syllabus or evidence changes. Do not automatically publish learner uploads, private notes or conversations to the community. Shared content needs explicit sharing and rights checks.

Current cache is bounded, process-local and short-lived, not a durable community library. Curriculum coverage, durable ingestion, teacher review and diagram-specific evaluators remain future work; they must not be presented as completed.
