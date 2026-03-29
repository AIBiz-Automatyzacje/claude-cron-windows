const fs = require('node:fs');
const path = require('node:path');
const matter = require('gray-matter');
const { SKILLS_DIR, GLOBAL_SKILLS_DIR, HOME } = require('./config');

const PLUGINS_DIR = path.join(HOME, '.claude', 'plugins');
const INSTALLED_PLUGINS_FILE = path.join(PLUGINS_DIR, 'installed_plugins.json');

function scanSkillsDir(skillsDir, source, pluginName) {
  if (!fs.existsSync(skillsDir)) return [];

  const dirs = fs.readdirSync(skillsDir, { withFileTypes: true })
    .filter(d => {
      if (d.isDirectory()) return true;
      if (d.isSymbolicLink()) {
        try {
          return fs.statSync(path.join(skillsDir, d.name)).isDirectory();
        } catch { return false; }
      }
      return false;
    })
    .map(d => d.name);

  const skills = [];
  for (const dir of dirs) {
    const skillFile = path.join(skillsDir, dir, 'SKILL.md');
    if (!fs.existsSync(skillFile)) continue;

    try {
      const raw = fs.readFileSync(skillFile, 'utf-8');
      const { data } = matter(raw);

      const skill = {
        name: data.name || dir,
        description: data.description || '',
        dir_name: pluginName ? `${pluginName}:${dir}` : dir,
        source,
        allowed_tools: data['allowed-tools'] || [],
        user_invocable: data['user-invocable'] !== false,
      };
      if (pluginName) skill.plugin = pluginName;

      skills.push(skill);
    } catch {
      // Skip unparseable skills
    }
  }

  return skills;
}

function scanPluginSkills() {
  if (!fs.existsSync(INSTALLED_PLUGINS_FILE)) return [];

  let installed;
  try {
    installed = JSON.parse(fs.readFileSync(INSTALLED_PLUGINS_FILE, 'utf-8'));
  } catch { return []; }

  const plugins = installed.plugins || {};
  const seen = new Set();
  const skills = [];

  for (const [key, entries] of Object.entries(plugins)) {
    for (const entry of entries) {
      const installPath = entry.installPath;
      if (!installPath || seen.has(installPath)) continue;
      seen.add(installPath);

      // Plugin name = part before @ in key (e.g. "hookify" from "hookify@claude-plugins-official")
      const pluginName = key.split('@')[0];

      // Direct skills: {installPath}/skills/
      const skillsPath = path.join(installPath, 'skills');
      skills.push(...scanSkillsDir(skillsPath, 'plugin', pluginName));

      // Nested plugin skills: {installPath}/plugins/*/skills/
      const nestedPluginsPath = path.join(installPath, 'plugins');
      if (fs.existsSync(nestedPluginsPath)) {
        try {
          const nestedDirs = fs.readdirSync(nestedPluginsPath, { withFileTypes: true })
            .filter(d => d.isDirectory())
            .map(d => d.name);
          for (const nd of nestedDirs) {
            const nestedSkillsPath = path.join(nestedPluginsPath, nd, 'skills');
            skills.push(...scanSkillsDir(nestedSkillsPath, 'plugin', pluginName));
          }
        } catch { /* skip */ }
      }
    }
  }

  return skills;
}

function getAllSkills() {
  const pluginSkills = scanPluginSkills();
  const userSkills = scanSkillsDir(GLOBAL_SKILLS_DIR, 'user');
  const projectSkills = scanSkillsDir(SKILLS_DIR, 'project');

  // Priority: project > user > plugin (by dir_name)
  const merged = new Map();
  for (const s of pluginSkills) merged.set(s.dir_name, s);
  for (const s of userSkills) merged.set(s.dir_name, s);
  for (const s of projectSkills) merged.set(s.dir_name, s);

  return [...merged.values()].sort((a, b) => a.name.localeCompare(b.name));
}

function getSkill(name) {
  return getAllSkills().find(s => s.dir_name === name || s.name === name) || null;
}

module.exports = { getAllSkills, getSkill };
