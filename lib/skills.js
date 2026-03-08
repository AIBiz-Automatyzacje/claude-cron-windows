const fs = require('node:fs');
const path = require('node:path');
const matter = require('gray-matter');
const { SKILLS_DIR } = require('./config');

function getAllSkills() {
  if (!fs.existsSync(SKILLS_DIR)) return [];

  const dirs = fs.readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  const skills = [];
  for (const dir of dirs) {
    const skillFile = path.join(SKILLS_DIR, dir, 'SKILL.md');
    if (!fs.existsSync(skillFile)) continue;

    try {
      const raw = fs.readFileSync(skillFile, 'utf-8');
      const { data } = matter(raw);

      skills.push({
        name: data.name || dir,
        description: data.description || '',
        dir_name: dir,
        allowed_tools: data['allowed-tools'] || [],
        user_invocable: data['user-invocable'] !== false,
      });
    } catch {
      // Skip unparseable skills
    }
  }

  return skills.sort((a, b) => a.name.localeCompare(b.name));
}

function getSkill(name) {
  return getAllSkills().find(s => s.dir_name === name || s.name === name) || null;
}

module.exports = { getAllSkills, getSkill };
