#!/bin/bash
cd /tmp/superbowl

RESULT=$(curl -s "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard" | python3 << 'PYEOF'
import sys, json, re
from datetime import datetime

data = json.load(sys.stdin)
event = data['events'][0]
comp = event['competitions'][0]
status_detail = comp['status']['type']['shortDetail']
status_state = comp['status']['type']['state']

teams = {}
for t in comp['competitors']:
    abbr = t['team']['abbreviation']
    teams[abbr] = {
        'score': t['score'],
        'quarters': [str(int(l.get('value',0))) for l in t.get('linescores', [])]
    }

sea = teams.get('SEA', {'score':'0','quarters':[]})
ne = teams.get('NE', {'score':'0','quarters':[]})

def qval(qs, i):
    return qs[i] if i < len(qs) else '-'

# Read current HTML
with open('index.html', 'r') as f:
    html = f.read()

ts = datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')

# Update main scores
html = re.sub(r'(<span class="score-sea">)[^<]*', f'\\g<1>{sea["score"]}', html)
html = re.sub(r'(<span class="score-ne">)[^<]*', f'\\g<1>{ne["score"]}', html)
html = re.sub(r'(<div class="quarter">)[^<]*', f'\\g<1>{status_detail}', html)
html = re.sub(r'(<div class="game-status">)[^<]*', f'\\g<1>Updated: {ts}', html)

# Update quarter table for SEA
sea_q = sea['quarters']
ne_q = ne['quarters']

# Replace quarter table rows using a more reliable method
lines = html.split('\n')
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    if 'var(--sea-green)' in line and 'SEA' in line:
        new_lines.append(line)
        # Next 5 lines are quarter cells + total
        for qi in range(4):
            i += 1
            val = qval(sea_q, qi)
            new_lines.append(f'                    <td>{val}</td>')
        i += 1
        new_lines.append(f'                    <td style="font-weight:700">{sea["score"]}</td>')
    elif 'var(--ne-red)' in line and 'NE' in line:
        new_lines.append(line)
        for qi in range(4):
            i += 1
            val = qval(ne_q, qi)
            new_lines.append(f'                    <td>{val}</td>')
        i += 1
        new_lines.append(f'                    <td style="font-weight:700">{ne["score"]}</td>')
    else:
        new_lines.append(line)
    i += 1

html = '\n'.join(new_lines)

# Update footer
html = re.sub(r'Score snapshot as of[^<]*', f'Auto-updated: {ts}', html)
html = re.sub(r'Auto-updated: [^<]*(?=</p>)', f'Auto-updated: {ts}', html)

# Update live badge based on game state
if status_state == 'post':
    html = html.replace('🔴 Game Day', '🏆 Final')
    html = re.sub(r"animation: pulse[^;]*;", '', html)

with open('index.html', 'w') as f:
    f.write(html)

print(f"SEA {sea['score']} - NE {ne['score']} | {status_detail}")
PYEOF
)

echo "$RESULT"

# Commit and push if changed
git add -A
if git diff --cached --quiet; then
    echo "No changes"
else
    git commit -m "🏈 $RESULT" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
    echo "✅ Pushed"
fi
