"""
Extract structured data from Gutachten / Exposé PDFs using pdfplumber.

Target fields:
  - Wohnfläche (sqm)
  - Grundstücksgröße (sqm)
  - Baujahr
  - Anzahl Zimmer
  - Raw full text (for AI analysis)
"""
from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

try:
    import pdfplumber
    _PDFPLUMBER_AVAILABLE = True
except ImportError:
    _PDFPLUMBER_AVAILABLE = False
    logger.warning("pdfplumber not installed — PDF extraction disabled")


def extract_pdf_data(pdf_path: str | Path) -> dict:
    """
    Extract key fields and full text from a Gutachten PDF.

    Returns a dict with keys:
      wohnflaeche_sqm, grundstueck_sqm, baujahr, zimmer, full_text
    """
    result = {
        "wohnflaeche_sqm": None,
        "grundstueck_sqm": None,
        "baujahr": None,
        "zimmer": None,
        "full_text": "",
    }

    if not _PDFPLUMBER_AVAILABLE:
        return result

    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        logger.warning("PDF not found: %s", pdf_path)
        return result

    try:
        with pdfplumber.open(pdf_path) as pdf:
            pages_text = []
            for page in pdf.pages:
                text = page.extract_text() or ""
                pages_text.append(text)
            full_text = "\n".join(pages_text)
    except Exception as exc:
        logger.error("Failed to read PDF %s: %s", pdf_path, exc)
        return result

    result["full_text"] = full_text
    result["wohnflaeche_sqm"] = _extract_wohnflaeche(full_text)
    result["grundstueck_sqm"] = _extract_grundstueck(full_text)
    result["baujahr"] = _extract_baujahr(full_text)
    result["zimmer"] = _extract_zimmer(full_text)

    return result


# ---------------------------------------------------------------------------
# Field extractors
# ---------------------------------------------------------------------------

def _extract_wohnflaeche(text: str) -> Optional[float]:
    patterns = [
        r"Wohnfl[äa]che\s*[:\-]?\s*([\d.,]+)\s*m[²2]",
        r"Wohnfl[äa]che\s*(?:ca\.?)?\s*([\d.,]+)\s*qm",
        r"(?:Wohn-?\s*und?\s*)?Nutzfl[äa]che\s*[:\-]?\s*([\d.,]+)\s*m[²2]",
        r"Wohnfl[äa]che\s*betr[äa]gt\s*(?:ca\.?)?\s*([\d.,]+)",
    ]
    return _first_float(text, patterns)


def _extract_grundstueck(text: str) -> Optional[float]:
    patterns = [
        r"Grundst[üu]cksfl[äa]che\s*[:\-]?\s*([\d.,]+)\s*m[²2]",
        r"Grundst[üu]cksfl[äa]che\s*(?:ca\.?)?\s*([\d.,]+)\s*qm",
        r"Grundst[üu]ck(?:sgr[öo][ß s]e)?\s*[:\-]?\s*([\d.,]+)\s*m[²2]",
        r"Fl[äa]che\s+(?:des\s+)?Grundst[üu]cks\s*[:\-]?\s*([\d.,]+)",
    ]
    return _first_float(text, patterns)


def _extract_baujahr(text: str) -> Optional[int]:
    patterns = [
        r"Baujahr\s*[:\-]?\s*(\d{4})",
        r"erbaut\s+(?:im\s+Jahr\s+)?(\d{4})",
        r"Errichtung\s+(?:im\s+Jahr\s+)?(\d{4})",
        r"Bj\.?\s*(\d{4})",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            year = int(m.group(1))
            if 1800 <= year <= 2030:
                return year
    return None


def _extract_zimmer(text: str) -> Optional[int]:
    patterns = [
        r"(\d+)\s+Zimmer",
        r"Zimmeranzahl\s*[:\-]?\s*(\d+)",
        r"(\d+)-Zimmer",
        r"Anzahl\s+(?:der\s+)?Zimmer\s*[:\-]?\s*(\d+)",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            z = int(m.group(1))
            if 1 <= z <= 30:
                return z
    return None


def _first_float(text: str, patterns: list[str]) -> Optional[float]:
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            raw = m.group(1).replace(".", "").replace(",", ".")
            try:
                val = float(raw)
                if val > 0:
                    return val
            except ValueError:
                pass
    return None
