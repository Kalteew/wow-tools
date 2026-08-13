from __future__ import annotations

import unittest

from wow_tools.mounts import parse_mount_detail, parse_search_page


SEARCH_FIXTURE = """
<p>Showing 1 - 1 of 1,234 mounts.</p>
<table id="results"><tr>
<td><a href='/mount.php?mountid=802'><img src='/images/thumbs/serpentmount_green.jpg'/></a>
<a href='/mount.php?mountid=802' class='searchname'>Abyss Worm</a></td>
<td class='centered'>10</td><td>apprentice</td><td>Flying</td><td></td>
</tr></table>
"""


DETAIL_FIXTURE = """
<html><head><meta property='og:image' content='https://example.test/mount.jpg'></head>
<body id='mount:test' class='mount achievement'>
<h2 id='mounttitle'><span id='mountname'>Test Drake</span></h2>
<h3>Riding Requirements:</h3><ul><li>Level 10</li></ul>
<h3>Source 1:</h3><ul><li>Reward for completing the <a href='https://www.wowhead.com/achievement=1'>achievement</a>.</li></ul>
<h3>Notes:</h3><span class='mountdata'>Guaranteed reward.</span>
<h3>Introduced in:</h3><span class='mountdata'>Patch 10.1</span>
<h3>Travel Mode:</h3><ul id='speedlist'><li>Flying</li></ul>
<h3>Blizzard ID:</h3>1234
<h3 id='wowheadlink'>More info on Wowhead</h3><a href='https://www.wowhead.com/spell=1234'>Test Drake</a>
</body></html>
"""


class MountsTests(unittest.TestCase):
    def test_parse_search_page(self) -> None:
        total, rows = parse_search_page(SEARCH_FIXTURE)
        self.assertEqual(total, 1234)
        self.assertEqual(rows[0]["warcraft_mounts_id"], 802)
        self.assertEqual(rows[0]["name"], "Abyss Worm")
        self.assertEqual(rows[0]["travel_mode"], "Flying")

    def test_parse_detail_computes_deterministic_mount(self) -> None:
        row = parse_mount_detail(
            DETAIL_FIXTURE,
            {
                "warcraft_mounts_id": 1,
                "name": "Test Drake",
                "is_upcoming": False,
                "required_level": "10",
                "riding_skill": "apprentice",
                "travel_mode": "Flying",
                "list_notes": "",
                "list_image_url": None,
            },
        )
        self.assertEqual(row["display_name"], "Test Drake")
        self.assertEqual(row["expansion"], "Dragonflight")
        self.assertEqual(row["reliability_score"], 100)
        self.assertTrue(row["is_always_obtainable"])
        self.assertEqual(row["wowhead_url"], "https://www.wowhead.com/spell=1234")
        self.assertEqual(row["image_url"], "https://example.test/mount.jpg")


if __name__ == "__main__":
    unittest.main()

