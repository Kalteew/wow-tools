import { WclNotFoundError, WclValidationError } from './errors.mjs';
import { extractMythicPlusMetrics } from './metrics.mjs';

export const CHARACTER_QUERY = `query CharacterMplus($name: String!, $serverSlug: String!, $serverRegion: String!) {
  characterData {
    character(name: $name, serverSlug: $serverSlug, serverRegion: $serverRegion) {
      id name classID level
      server { name slug region { name slug } }
      rankings(metric: points_and_damage)
    }
  }
}`;

export async function resolveCharacter(client, { name, realm, region }) {
  if (!name || !realm || !region) throw new WclValidationError('Character name, realm and region are required.');
  const serverSlug = slugify(realm);
  const serverRegion = normalizeRegion(region);
  const data = await client.query(CHARACTER_QUERY, { name, serverSlug, serverRegion });
  const character = data.characterData?.character ?? data.character;
  if (!character) throw new WclNotFoundError(`WCL character not found: ${name}-${realm}-${region}.`);
  return {
    id: character.id ?? null,
    name: character.name ?? name,
    classId: character.classID ?? character.classId ?? null,
    level: character.level ?? null,
    server: character.server ?? { name: realm, slug: serverSlug, region: { slug: serverRegion } },
    lookup: { name, realm, region: serverRegion, serverSlug },
    mplus: extractMythicPlusMetrics(character.rankings ?? character.mythicPlus ?? character),
  };
}

export function slugify(value) {
  return String(value).normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

export function normalizeRegion(value) {
  const region = String(value).trim().toUpperCase();
  if (!['US', 'EU', 'KR', 'TW'].includes(region)) throw new WclValidationError(`Unsupported WCL region: ${value}.`);
  return region;
}
