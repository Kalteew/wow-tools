const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const ROOT = path.resolve(__dirname, "..");
const SERVER_JSON_PATH = path.join(ROOT, "server.json");
const RAIDERIO_URL = "https://raider.io/realms/eu";
const USER_PRESENT_REALMS = [
  "Hyjal",
  "Sargeras",
  "Vol'jin",
  "Magtheridon",
  "Ragnaros",
  "Throk'Feroth",
  "Khaz Modan",
];

const REALM_ALIASES = new Map([
  ["revolving fjord", "howling-fjord"],
  ["gor'dunni", "gordunni"],
  ["well of eternity", "pozzo-delleternità"],
  ["свежеватель душ", "soulflayer"],
  ["пиратская бухта", "booty-bay"],
  ["коль-лич", "lich-king"],
  ["дракономор", "fordragon"],
  ["азурегос", "azuregos"],
  ["вечная песня", "eversong"],
]);

function normalizeLookupName(name) {
  let value = name.trim();
  if (value.startsWith("Connected ")) {
    value = value.slice("Connected ".length);
  }
  const lowered = value.toLowerCase();
  return REALM_ALIASES.get(lowered) || lowered;
}

function normalizeCompareName(name) {
  return name
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/['’]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function slugifyRealmName(name) {
  return name
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\((.*?)\)/g, "$1")
    .replace(/['’]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
}

const USER_PRESENT_REALM_SET = new Set(USER_PRESENT_REALMS.map(normalizeCompareName));

function parsePopulationCharacters(value) {
  const match = value.match(/(\d+)\s*k\+\s*characters/i);
  return match ? Number.parseInt(match[1], 10) * 1000 : null;
}

function parsePopulationSummary(value) {
  const compact = value.replace(/\s+/g, " ").trim();
  const match = compact.match(
    /^(Alliance Dominant|Horde Dominant|Balanced)?\s*(Low Population|Medium Population|High Population)\s*(\d+k\+\s*characters)\s*(\d+%\s*[AH]\s*\/\s*\d+%\s*[AH])?$/i
  );
  if (!match) {
    return {
      dominance: compact,
      label: "",
      size: "",
      split: "",
    };
  }
  return {
    dominance: (match[1] || "").trim(),
    label: (match[2] || "").trim(),
    size: (match[3] || "").replace(/\s+/g, " ").trim(),
    split: (match[4] || "").replace(/\s+/g, " ").trim(),
  };
}

function parseFactionSplit(value) {
  const match = value.match(/(\d+)%\s*([AH])\s*\/\s*(\d+)%\s*([AH])/i);
  if (!match) {
    return null;
  }
  const firstPct = Number.parseInt(match[1], 10);
  const secondPct = Number.parseInt(match[3], 10);
  return {
    alliance_pct: match[2].toUpperCase() === "A" ? firstPct : secondPct,
    horde_pct: match[2].toUpperCase() === "H" ? firstPct : secondPct,
  };
}

async function scrapeRaiderIoRows() {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1600, height: 2600 } });
    await page.goto(RAIDERIO_URL, { waitUntil: "networkidle" });
    await page.waitForTimeout(2000);

    return await page.$$eval(".rt-tbody .rt-tr-group", (groups) =>
      groups.map((group) => {
        const row = group.querySelector(".rt-tr");
        const cells = row ? Array.from(row.querySelectorAll(".rt-td")) : [];
        const realmLinks = Array.from(group.querySelectorAll("a.rio-realm-link"));
        const populationLines = (
          cells[3]?.querySelector(".rio-simple-tt .top div")?.innerText || ""
        )
          .split("\n")
          .map((line) => line.trim())
          .filter(Boolean);

        return {
          realms: realmLinks.map((anchor) => ({
            name: (anchor.textContent || "").trim(),
            slug: (anchor.getAttribute("href") || "").split("/").filter(Boolean).pop(),
          })),
          language: cells[1]?.innerText.trim() || "",
          timezone: cells[2]?.innerText.trim() || "",
          population_lines: populationLines,
        };
      })
    );
  } finally {
    await browser.close();
  }
}

function buildGroupIndex(rows) {
  const bySlug = new Map();
  for (const row of rows) {
    const populationSummary = parsePopulationSummary(row.population_lines.join(" "));
    const dominance = populationSummary.dominance;
    const population = populationSummary.label;
    const characters = populationSummary.size;
    const split = populationSummary.split;
    const splitData = parseFactionSplit(split);
    const entry = {
      raiderio_region: "eu",
      raiderio_group_realms: row.realms.map((realm) => realm.name),
      raiderio_group_realm_slugs: row.realms.map((realm) => realm.slug),
      raiderio_group_realm_count: row.realms.length,
      raiderio_language: row.language,
      raiderio_timezone: row.timezone,
      raiderio_population_label: population,
      raiderio_population_size: characters,
      raiderio_population_characters_min: parsePopulationCharacters(characters),
      raiderio_population_dominance: dominance,
      raiderio_population_split: split,
      ...(splitData || {}),
    };

    const userPresentRealmsInGroup = row.realms
      .map((realm) => realm.name)
      .filter((realmName) => USER_PRESENT_REALM_SET.has(normalizeCompareName(realmName)));
    entry.user_present_on_connected_group = userPresentRealmsInGroup.length > 0;
    entry.user_present_realms_in_connected_group = userPresentRealmsInGroup;

    for (const realm of row.realms) {
      bySlug.set(realm.slug.toLowerCase(), entry);
      bySlug.set(slugifyRealmName(realm.name), entry);
    }
  }
  return bySlug;
}

async function main() {
  const rows = await scrapeRaiderIoRows();
  const index = buildGroupIndex(rows);
  const servers = JSON.parse(fs.readFileSync(SERVER_JSON_PATH, "utf8"));

  const missing = [];
  let updated = 0;

  for (const server of servers) {
    const lookup = normalizeLookupName(server.name);
    const key = lookup.includes("-") ? lookup : slugifyRealmName(lookup);
    const data = index.get(key) || index.get(lookup);
    if (!data) {
      missing.push(server.name);
      continue;
    }
    Object.assign(server, data);
    updated += 1;
  }

  fs.writeFileSync(SERVER_JSON_PATH, `${JSON.stringify(servers, null, 2)}\n`, "utf8");

  console.log(`updated=${updated}`);
  if (missing.length) {
    console.log("missing=");
    for (const name of missing) {
      console.log(name);
    }
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
