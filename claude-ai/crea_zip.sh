#!/bin/sh
# Crea claude-ai/ghostwriter-skill.zip da caricare su claude.ai (Impostazioni → Funzionalità → Skill).
set -e
cd "$(dirname "$0")/../.claude/skills"
rm -f ../../claude-ai/ghostwriter-skill.zip
zip -r -X ../../claude-ai/ghostwriter-skill.zip ghostwriter -x '*/__pycache__/*'
