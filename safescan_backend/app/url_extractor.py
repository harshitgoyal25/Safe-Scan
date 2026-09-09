from __future__ import annotations

import ipaddress
import math
import re
from collections import Counter
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit


# This extractor is a SafeScan reconstruction of the lexical/structural
# ISCX-URL2016 feature definitions. The dataset exposes 79 features, but
# SafeScan's trained model intentionally uses the 78 numeric features and
# excludes the categorical `tld` field.
MODEL_FEATURES = [
    "Querylength",
    "domain_token_count",
    "path_token_count",
    "avgdomaintokenlen",
    "longdomaintokenlen",
    "avgpathtokenlen",
    "charcompvowels",
    "charcompace",
    "ldl_url",
    "ldl_domain",
    "ldl_path",
    "ldl_filename",
    "ldl_getArg",
    "dld_url",
    "dld_domain",
    "dld_path",
    "dld_filename",
    "dld_getArg",
    "urlLen",
    "domainlength",
    "pathLength",
    "subDirLen",
    "fileNameLen",
    "this.fileExtLen",
    "ArgLen",
    "pathurlRatio",
    "ArgUrlRatio",
    "argDomanRatio",
    "domainUrlRatio",
    "pathDomainRatio",
    "argPathRatio",
    "executable",
    "isPortEighty",
    "NumberofDotsinURL",
    "ISIpAddressInDomainName",
    "CharacterContinuityRate",
    "LongestVariableValue",
    "URL_DigitCount",
    "host_DigitCount",
    "Directory_DigitCount",
    "File_name_DigitCount",
    "Extension_DigitCount",
    "Query_DigitCount",
    "URL_Letter_Count",
    "host_letter_count",
    "Directory_LetterCount",
    "Filename_LetterCount",
    "Extension_LetterCount",
    "Query_LetterCount",
    "LongestPathTokenLength",
    "Domain_LongestWordLength",
    "Path_LongestWordLength",
    "sub-Directory_LongestWordLength",
    "Arguments_LongestWordLength",
    "URL_sensitiveWord",
    "URLQueries_variable",
    "spcharUrl",
    "delimeter_Domain",
    "delimeter_path",
    "delimeter_Count",
    "NumberRate_URL",
    "NumberRate_Domain",
    "NumberRate_DirectoryName",
    "NumberRate_FileName",
    "NumberRate_Extension",
    "NumberRate_AfterPath",
    "SymbolCount_URL",
    "SymbolCount_Domain",
    "SymbolCount_Directoryname",
    "SymbolCount_FileName",
    "SymbolCount_Extension",
    "SymbolCount_Afterpath",
    "Entropy_URL",
    "Entropy_Domain",
    "Entropy_DirectoryName",
    "Entropy_Filename",
    "Entropy_Extension",
    "Entropy_Afterpath",
]

TOKEN_RE = re.compile(r"[A-Za-z0-9]+")
LDL_RE = re.compile(r"[A-Za-z][0-9][A-Za-z]")
DLD_RE = re.compile(r"[0-9][A-Za-z][0-9]")

DELIMITERS = set(".:/?=,;()[]{}+-_")
SPECIAL_CHARS = set("@%&=;:$,!?+#~*|\\<>^`\"'")
EXECUTABLE_EXTENSIONS = {
    "exe", "scr", "bat", "cmd", "com", "msi", "jar", "apk", "bin", "dll"
}

SENSITIVE_WORDS = {
    "account", "authorize", "authorization", "bank", "billing", "confirm",
    "credential", "login", "log-in", "password", "paypal", "recover",
    "signin", "sign-in", "secure", "security", "unlock", "update",
    "verify", "verification", "wallet", "webscr", "admin"
}


def _tokens(value: str) -> list[str]:
    return TOKEN_RE.findall(value or "")


def _longest_token(value: str, default: int = 0) -> int:
    tokens = _tokens(value)
    return max((len(t) for t in tokens), default=default)


def _avg_token_length(value: str) -> float:
    tokens = _tokens(value)
    if not tokens:
        return 0.0
    return sum(map(len, tokens)) / len(tokens)


def _ratio(numerator: float, denominator: float) -> float:
    if denominator == 0:
        return float("nan")
    return numerator / denominator


def _count_pattern(value: str, pattern: re.Pattern[str]) -> int:
    return len(pattern.findall(value or ""))


def _digit_count(value: str) -> int:
    return sum(ch.isdigit() for ch in (value or ""))


def _letter_count(value: str) -> int:
    return sum(ch.isalpha() for ch in (value or ""))


def _symbol_count(value: str) -> int:
    return sum(not ch.isalnum() for ch in (value or ""))


def _delimiter_count(value: str) -> int:
    return sum(ch in DELIMITERS for ch in (value or ""))


def _entropy(value: str) -> float:
    if not value:
        return float("nan")

    counts = Counter(value)
    n = len(value)

    entropy = 0.0
    for count in counts.values():
        p = count / n
        entropy -= p * math.log2(p)

    # The ISCX-URL2016 entropy features are bounded approximately to [0, 1].
    if n <= 1:
        return 0.0

    max_entropy = math.log2(min(n, len(counts)))
    if max_entropy == 0:
        return 0.0

    return entropy / max_entropy


def _character_continuity_rate(value: str) -> float:
    if not value:
        return float("nan")

    def kind(ch: str) -> str:
        if ch.isalpha():
            return "letter"
        if ch.isdigit():
            return "digit"
        return "symbol"

    longest = {"letter": 0, "digit": 0, "symbol": 0}
    current_kind = None
    current_length = 0

    for ch in value:
        k = kind(ch)
        if k == current_kind:
            current_length += 1
        else:
            current_kind = k
            current_length = 1
        longest[k] = max(longest[k], current_length)

    return sum(longest.values()) / len(value)


def _ip_in_hostname(host: str) -> int:
    if not host:
        return 0
    try:
        ipaddress.ip_address(host)
        return 1
    except ValueError:
        return 0


def _query_variable_values(query: str) -> list[str]:
    if not query:
        return []
    try:
        pairs = parse_qsl(query, keep_blank_values=True)
        if pairs:
            return [value for _, value in pairs]
    except Exception:
        pass

    values = []
    for item in query.split("&"):
        if "=" in item:
            values.append(item.split("=", 1)[1])
    return values


def _filename_parts(path: str) -> tuple[str, str, str]:
    clean = path.rstrip("/")
    if not clean:
        return "", "", ""

    filename = clean.rsplit("/", 1)[-1]
    if "." in filename and not filename.startswith("."):
        extension = filename.rsplit(".", 1)[-1]
    else:
        extension = ""

    return filename, extension, clean


def extract_url_features(url: str) -> dict[str, float]:
    if not isinstance(url, str):
        raise ValueError("URL must be a string.")

    url = url.strip()
    if not url:
        raise ValueError("URL cannot be empty.")

    # urlsplit needs a scheme to reliably identify the hostname.
    parse_target = url if "://" in url else "http://" + url
    parsed = urlsplit(parse_target)

    host = parsed.hostname or ""
    path = parsed.path or ""
    query = parsed.query or ""

    filename, extension, clean_path = _filename_parts(path)

    # The dataset uses the path/sub-directory terminology in a way that can
    # leave subDirLen equal to pathLength for URLs without a separately
    # represented filename. Keep the raw path length here.
    directory = clean_path
    after_path = query

    domain_tokens = _tokens(host)
    path_tokens = _tokens(path)
    url_tokens = _tokens(url)
    query_values = _query_variable_values(query)

    domain_len = len(host)
    path_len = len(path)
    filename_len = len(filename)
    extension_len = len(extension)
    arg_len = len(query)
    url_len = len(url)

    features = {
        "Querylength": len(query),
        "domain_token_count": len(domain_tokens),
        "path_token_count": len(path_tokens),
        "avgdomaintokenlen": _avg_token_length(host),
        "longdomaintokenlen": _longest_token(host),
        "avgpathtokenlen": _avg_token_length(path),
        "charcompvowels": sum(ch.lower() in "aeiou" for ch in url),
        "charcompace": _symbol_count(url),

        "ldl_url": _count_pattern(url, LDL_RE),
        "ldl_domain": _count_pattern(host, LDL_RE),
        "ldl_path": _count_pattern(path, LDL_RE),
        "ldl_filename": _count_pattern(filename, LDL_RE),
        "ldl_getArg": _count_pattern(query, LDL_RE),

        "dld_url": _count_pattern(url, DLD_RE),
        "dld_domain": _count_pattern(host, DLD_RE),
        "dld_path": _count_pattern(path, DLD_RE),
        "dld_filename": _count_pattern(filename, DLD_RE),
        "dld_getArg": _count_pattern(query, DLD_RE),

        "urlLen": url_len,
        "domainlength": domain_len,
        "pathLength": path_len,
        "subDirLen": path_len,
        "fileNameLen": filename_len,
        "this.fileExtLen": extension_len,
        "ArgLen": arg_len,

        "pathurlRatio": _ratio(path_len, url_len),
        "ArgUrlRatio": _ratio(arg_len, url_len),
        "argDomanRatio": _ratio(arg_len, domain_len),
        "domainUrlRatio": _ratio(domain_len, url_len),
        "pathDomainRatio": _ratio(path_len, domain_len),
        "argPathRatio": _ratio(arg_len, path_len),

        "executable": int(extension.lower() in EXECUTABLE_EXTENSIONS),
        "isPortEighty": int(parsed.port == 80) if parsed.port is not None else 0,
        "NumberofDotsinURL": url.count("."),
        "ISIpAddressInDomainName": _ip_in_hostname(host),
        "CharacterContinuityRate": _character_continuity_rate(url),
        "LongestVariableValue": (
            max((len(v) for v in query_values), default=-1)
        ),

        "URL_DigitCount": _digit_count(url),
        "host_DigitCount": _digit_count(host),
        "Directory_DigitCount": _digit_count(directory),
        "File_name_DigitCount": _digit_count(filename),
        "Extension_DigitCount": _digit_count(extension),
        "Query_DigitCount": _digit_count(query),

        "URL_Letter_Count": _letter_count(url),
        "host_letter_count": _letter_count(host),
        "Directory_LetterCount": _letter_count(directory),
        "Filename_LetterCount": _letter_count(filename),
        "Extension_LetterCount": _letter_count(extension),
        "Query_LetterCount": _letter_count(query),

        "LongestPathTokenLength": _longest_token(path),
        "Domain_LongestWordLength": _longest_token(host),
        "Path_LongestWordLength": _longest_token(path),
        "sub-Directory_LongestWordLength": _longest_token(directory),
        "Arguments_LongestWordLength": _longest_token(query, default=-1),

        "URL_sensitiveWord": sum(
            1 for word in SENSITIVE_WORDS if word in url.lower()
        ),
        "URLQueries_variable": sum(
            1 for item in query.split("&") if item.strip() and "=" in item
        ),
        "spcharUrl": sum(ch in SPECIAL_CHARS for ch in url),

        "delimeter_Domain": _delimiter_count(host),
        "delimeter_path": _delimiter_count(path),
        "delimeter_Count": _delimiter_count(url),

        "NumberRate_URL": _ratio(_digit_count(url), url_len),
        "NumberRate_Domain": _ratio(_digit_count(host), domain_len),
        "NumberRate_DirectoryName": _ratio(
            _digit_count(directory), len(directory)
        ),
        "NumberRate_FileName": _ratio(
            _digit_count(filename), filename_len
        ),
        "NumberRate_Extension": _ratio(
            _digit_count(extension), extension_len
        ),
        "NumberRate_AfterPath": _ratio(
            _digit_count(after_path), len(after_path)
        ),

        "SymbolCount_URL": _symbol_count(url),
        "SymbolCount_Domain": _symbol_count(host),
        "SymbolCount_Directoryname": _symbol_count(directory),
        "SymbolCount_FileName": _symbol_count(filename),
        "SymbolCount_Extension": _symbol_count(extension),
        "SymbolCount_Afterpath": _symbol_count(after_path),

        "Entropy_URL": _entropy(url),
        "Entropy_Domain": _entropy(host),
        "Entropy_DirectoryName": _entropy(directory),
        "Entropy_Filename": _entropy(filename),
        "Entropy_Extension": _entropy(extension),
        "Entropy_Afterpath": _entropy(after_path),
    }

    missing = [name for name in MODEL_FEATURES if name not in features]
    if missing:
        raise RuntimeError(f"Missing URL features: {missing}")

    return {name: features[name] for name in MODEL_FEATURES}
