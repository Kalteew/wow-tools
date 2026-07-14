from __future__ import annotations

import re
from typing import Any


_NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")
_IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


class LuaTableParser:
    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0

    def parse_assignments(self) -> dict[str, Any]:
        result: dict[str, Any] = {}
        self._skip_ignored()

        while not self._eof():
            name = self._parse_identifier()
            self._skip_ignored()
            self._expect("=")
            self._skip_ignored()
            result[name] = self._parse_value()
            self._skip_ignored()

        return result

    def parse_value(self) -> Any:
        self._skip_ignored()
        value = self._parse_value()
        self._skip_ignored()
        return value

    def _parse_value(self) -> Any:
        self._skip_ignored()
        char = self._peek()

        if char == "{":
            return self._parse_table()
        if char in ('"', "'"):
            return self._parse_string()
        if char == "-" or char.isdigit():
            return self._parse_number()
        if char.isalpha() or char == "_":
            word = self._parse_identifier()
            if word == "true":
                return True
            if word == "false":
                return False
            if word == "nil":
                return None
            return word

        raise ValueError(f"Unexpected character {char!r} at position {self.pos}")

    def _parse_table(self) -> dict[Any, Any]:
        self._expect("{")
        table: dict[Any, Any] = {}
        array_index = 1

        while True:
            self._skip_ignored()
            if self._peek() == "}":
                self._advance()
                break

            if self._peek() == "[":
                self._advance()
                self._skip_ignored()
                key = self._parse_value()
                self._skip_ignored()
                self._expect("]")
                self._skip_ignored()
                self._expect("=")
                self._skip_ignored()
                value = self._parse_value()
                table[key] = value
            else:
                saved_pos = self.pos
                key = None

                if self._peek().isalpha() or self._peek() == "_":
                    key = self._parse_identifier()
                    self._skip_ignored()
                    if self._peek() == "=":
                        self._advance()
                        self._skip_ignored()
                        table[key] = self._parse_value()
                    else:
                        self.pos = saved_pos
                        table[array_index] = self._parse_value()
                        array_index += 1
                else:
                    table[array_index] = self._parse_value()
                    array_index += 1

            self._skip_ignored()
            if self._peek() in {",", ";"}:
                self._advance()

        return table

    def _parse_string(self) -> str:
        quote = self._peek()
        self._expect(quote)
        chars: list[str] = []

        while True:
            if self._eof():
                raise ValueError("Unterminated string")

            char = self._peek()
            self._advance()

            if char == quote:
                break
            if char == "\\":
                if self._eof():
                    raise ValueError("Unterminated escape")
                escaped = self._peek()
                self._advance()
                chars.append(
                    {
                        "n": "\n",
                        "r": "\r",
                        "t": "\t",
                        "\\": "\\",
                        '"': '"',
                        "'": "'",
                    }.get(escaped, escaped)
                )
            else:
                chars.append(char)

        return "".join(chars)

    def _parse_number(self) -> int | float:
        match = _NUMBER_RE.match(self.text, self.pos)
        if not match:
            raise ValueError(f"Invalid number at position {self.pos}")
        self.pos = match.end()
        value = match.group(0)
        return float(value) if "." in value else int(value)

    def _parse_identifier(self) -> str:
        match = _IDENT_RE.match(self.text, self.pos)
        if not match:
            raise ValueError(f"Expected identifier at position {self.pos}")
        self.pos = match.end()
        return match.group(0)

    def _skip_ignored(self) -> None:
        while not self._eof():
            char = self._peek()
            if char.isspace():
                self._advance()
                continue
            if self.text.startswith("--", self.pos):
                self.pos += 2
                while not self._eof() and self._peek() not in "\r\n":
                    self._advance()
                continue
            break

    def _peek(self) -> str:
        return self.text[self.pos] if not self._eof() else ""

    def _expect(self, char: str) -> None:
        if self._peek() != char:
            raise ValueError(f"Expected {char!r} at position {self.pos}")
        self._advance()

    def _advance(self) -> None:
        self.pos += 1

    def _eof(self) -> bool:
        return self.pos >= len(self.text)


def parse_lua_assignments(text: str) -> dict[str, Any]:
    return LuaTableParser(text).parse_assignments()


def parse_lua_value(text: str) -> Any:
    stripped = text.strip()
    if stripped.startswith("return "):
        stripped = stripped[len("return ") :].strip()
    return LuaTableParser(stripped).parse_value()
