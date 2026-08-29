import json, sys, re
from app.domain.search_query import SearchQuery
from app.domain.referent_context import ResultReferentContext
from app.domain.conversation_session import SearchConversationSession
from app.domain.search_intent import SearchIntent
from app.services.conversational_search_service import ConversationalSearchService as S
from benchmarks.scoring.system_scoring import _session_from_benchmark_context

OUT = sys.argv[1]
prev = {json.loads(l)['case_id']: json.loads(l) for l in open(f'{OUT}/replay_previous.jsonl')}
curr = {json.loads(l)['case_id']: json.loads(l) for l in open(f'{OUT}/replay_current.jsonl')}

# ---- case diff ----
diff_rows = []
fixed = regressed = equiv = 0
for cid in sorted(prev):
    p = prev[cid]['sys_score']; c = curr[cid]['sys_score']
    if p['system_success'] == c['system_success'] and p['outcome'] == c['outcome']:
        continue
    if c['system_success'] and not p['system_success']:
        cls = 'FIXED'; fixed += 1
    elif p['system_success'] and not c['system_success']:
        cls = 'REGRESSED'; regressed += 1
    else:
        cls = 'DIFFERENT_BUT_EQUIVALENT'; equiv += 1
    diff_rows.append({
        'case_id': cid, 'category': prev[cid]['category'], 'input_text': prev[cid]['input_text'],
        'conversation_context': prev[cid].get('conversation_context'),
        'frozen_intent': prev[cid]['intent'],
        'previous_outcome': p['outcome'], 'current_outcome': c['outcome'],
        'previous_success': p['system_success'], 'current_success': c['system_success'],
        'classification': cls,
    })
with open(f'{OUT}/case_diff.jsonl', 'w') as f:
    for r in diff_rows:
        f.write(json.dumps(r) + '\n')

# ---- ACC activation counts across full frozen set (mirror orchestrator order) ----
acc2_country = acc2_year = acc1_intent = acc4_ref = 0
acc2_cases = []
for cid, rec in curr.items():
    q = SearchQuery.model_validate(rec['parsed_query'])
    raw = rec['input_text']
    session = _session_from_benchmark_context({'conversation_context': rec.get('conversation_context')})
    q0, _ = S._neutralize_ungrounded_temporal_filters(q, raw, session)
    q1 = S._recover_grounded_direct_filters(q0, raw)
    if list(q1.countries) != list(q0.countries):
        acc2_country += 1
        acc2_cases.append({'case_id': cid, 'input': raw, 'added_countries': [x for x in q1.countries if x not in q0.countries]})
    if list(q1.years) != list(q0.years):
        acc2_year += 1
    q2 = S._recover_followup_video_intent(q1, raw, session.referents)
    if q2.intent != q1.intent:
        acc1_intent += 1
    q3 = S._apply_referent_fallback(q2, session.referents)
    if q3.model_dump() != q2.model_dump():
        acc4_ref += 1

analysis = {
    'previous_success': sum(1 for c in prev.values() if c['sys_score']['system_success']),
    'current_success': sum(1 for c in curr.values() if c['sys_score']['system_success']),
    'previous_false_confident': sum(1 for c in prev.values() if c['sys_score'].get('false_confident')),
    'current_false_confident': sum(1 for c in curr.values() if c['sys_score'].get('false_confident')),
    'fixed': fixed, 'regressed': regressed, 'different_but_equivalent': equiv,
    'acc2_country_activations': acc2_country, 'acc2_year_activations': acc2_year,
    'acc2_cases': acc2_cases,
    'acc1_intent_corrections': acc1_intent, 'acc4_referent_fallbacks': acc4_ref,
    'note_on_conversation_features': 'ACC-1/3/4 are conversation features; the frozen 392-set is predominantly single-turn, so they are exercised primarily by the separate conversation benchmark, not this replay.',
}
with open(f'{OUT}/failure_analysis.json', 'w') as f:
    json.dump(analysis, f, indent=2)
print(json.dumps(analysis, indent=2))
