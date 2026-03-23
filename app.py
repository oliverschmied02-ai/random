"""
ZVG Intelligence — Streamlit GUI
Run with:  streamlit run app.py
"""
from __future__ import annotations

import json
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path
from queue import Empty, Queue

import streamlit as st

# ── page config (must be first Streamlit call) ──────────────────────────────
st.set_page_config(
    page_title="ZVG Intelligence",
    page_icon="🏠",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── paths ────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent
DB_PATH = ROOT / "data" / "zvg.db"
REPORTS_DIR = ROOT / "reports"
CONFIG_PATH = ROOT / "config.yaml"
ENV_PATH = ROOT / ".env"
SECRETS_DIR = ROOT / "secrets"

# ── helpers ──────────────────────────────────────────────────────────────────

def load_config_yaml() -> dict:
    import yaml
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH) as f:
            return yaml.safe_load(f) or {}
    return {}


def save_config_yaml(data: dict) -> None:
    import yaml
    with open(CONFIG_PATH, "w") as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False)


def load_env() -> dict:
    env = {}
    if ENV_PATH.exists():
        for line in ENV_PATH.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env


def save_env(data: dict) -> None:
    lines = [f"{k}={v}" for k, v in data.items() if v]
    ENV_PATH.write_text("\n".join(lines) + "\n")


def get_all_listings() -> list[dict]:
    if not DB_PATH.exists():
        return []
    try:
        sys.path.insert(0, str(ROOT))
        from src.storage.local_db import ListingDB
        db = ListingDB(DB_PATH)
        db.init()
        return [l.to_dict() for l in db.get_all()]
    except Exception as exc:
        st.error(f"Datenbank-Fehler: {exc}")
        return []


def fmt_eur(val) -> str:
    if val is None:
        return "–"
    return f"{float(val):,.0f} €".replace(",", ".")


def score_color(score) -> str:
    if score is None:
        return "#888"
    if score >= 8: return "#2e7d32"
    if score >= 6: return "#f57f17"
    return "#c62828"


BUNDESLAENDER = [
    "Baden-Württemberg", "Bayern", "Berlin", "Brandenburg", "Bremen",
    "Hessen", "Niedersachsen", "Nordrhein-Westfalen", "Rheinland-Pfalz",
    "Saarland", "Sachsen", "Sachsen-Anhalt", "Schleswig-Holstein", "Thüringen",
]

# ── sidebar ───────────────────────────────────────────────────────────────────

with st.sidebar:
    st.markdown("## 🏠 ZVG Intelligence")
    st.markdown("---")
    page = st.radio(
        "Navigation",
        ["📊 Dashboard", "🔍 Suche starten", "📋 Alle Objekte", "⚙️ Einstellungen"],
        label_visibility="collapsed",
    )
    st.markdown("---")

    # Quick stats
    listings = get_all_listings()
    active = [l for l in listings if l.get("status") == "active"]
    st.metric("Gesamt gespeichert", len(listings))
    st.metric("Aktive Termine", len(active))

    report_html = REPORTS_DIR / "dashboard.html"
    if report_html.exists():
        with open(report_html, "rb") as f:
            st.download_button(
                "📥 HTML-Report laden",
                f,
                file_name="zvg_dashboard.html",
                mime="text/html",
                use_container_width=True,
            )

    csv_path = REPORTS_DIR / "listings_master.csv"
    if csv_path.exists():
        with open(csv_path, "rb") as f:
            st.download_button(
                "📥 CSV laden",
                f,
                file_name="zvg_listings.csv",
                mime="text/csv",
                use_container_width=True,
            )

# ═══════════════════════════════════════════════════════════════════════════════
# PAGE: DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════
if page == "📊 Dashboard":
    st.title("📊 Dashboard")

    if not listings:
        st.info(
            "Noch keine Daten vorhanden. "
            "Gehe zu **🔍 Suche starten** um Objekte zu laden."
        )
        st.stop()

    import pandas as pd

    df = pd.DataFrame(listings)

    # ── KPI row ──
    col1, col2, col3, col4 = st.columns(4)
    avg_score = df["ai_attractiveness_score"].dropna().mean()
    avg_vw = df["verkehrswert"].dropna().mean()
    scored = df["ai_attractiveness_score"].notna().sum()

    col1.metric("Objekte gesamt", len(df))
    col2.metric("Aktive Termine", len(df[df["status"] == "active"]))
    col3.metric("Ø Verkehrswert", fmt_eur(avg_vw))
    col4.metric("Ø AI-Score", f"{avg_score:.1f}/10" if scored else "–")

    st.markdown("---")

    # ── Map ──
    geo = df[df["lat"].notna() & df["lon"].notna()]
    if not geo.empty:
        st.subheader("🗺️ Karte")
        try:
            import folium
            from streamlit_folium import st_folium

            center = [geo["lat"].mean(), geo["lon"].mean()]
            m = folium.Map(location=center, zoom_start=9)
            for _, row in geo.iterrows():
                score = row.get("ai_attractiveness_score")
                color = "green" if score and score >= 7 else "orange" if score and score >= 4 else "red"
                popup = folium.Popup(
                    f"<b>{row['aktenzeichen']}</b><br>"
                    f"{row['amtsgericht']}<br>"
                    f"Verkehrswert: {fmt_eur(row['verkehrswert'])}<br>"
                    f"Score: {score or '–'}/10",
                    max_width=220,
                )
                folium.CircleMarker(
                    location=[row["lat"], row["lon"]],
                    radius=9, color=color, fill=True,
                    popup=popup, tooltip=row["aktenzeichen"],
                ).add_to(m)
            st_folium(m, use_container_width=True, height=420)
        except ImportError:
            st.warning("Für die Karte: `pip install streamlit-folium`")
    else:
        st.info("Noch keine Geodaten — starte die Analyse um Koordinaten zu laden.")

    # ── Top Picks ──
    st.subheader("⭐ Top Objekte (nach AI-Score)")
    top = (
        df[df["status"] == "active"]
        .sort_values("ai_attractiveness_score", ascending=False)
        .head(10)
    )

    if top.empty:
        st.info("Noch keine AI-Scores vorhanden. Starte die Analyse mit gesetztem ANTHROPIC_API_KEY.")
    else:
        for _, row in top.iterrows():
            score = row.get("ai_attractiveness_score")
            with st.container():
                c1, c2, c3, c4 = st.columns([3, 2, 2, 1])
                c1.markdown(f"**{row['aktenzeichen']}** · {row['amtsgericht']}")
                c2.markdown(f"📍 {row['plz']} {row['ort']}")
                c3.markdown(f"💶 {fmt_eur(row['verkehrswert'])}")
                color = score_color(score)
                c4.markdown(
                    f"<span style='color:{color};font-size:1.3em;font-weight:bold'>"
                    f"{score or '–'}/10</span>",
                    unsafe_allow_html=True,
                )
                if row.get("ai_summary"):
                    st.caption(row["ai_summary"])
                if row.get("ai_risk_flags"):
                    st.caption(f"⚠️ {row['ai_risk_flags']}")
                st.markdown("---")

    # ── Verkehrswert histogram ──
    vw = df["verkehrswert"].dropna()
    if not vw.empty:
        st.subheader("💰 Verkehrswert-Verteilung")
        try:
            import plotly.express as px
            fig = px.histogram(
                vw / 1000, nbins=30,
                labels={"value": "Verkehrswert (Tsd. €)", "count": "Anzahl"},
                color_discrete_sequence=["#1F4E79"],
            )
            fig.update_layout(showlegend=False, height=300, margin=dict(t=20))
            st.plotly_chart(fig, use_container_width=True)
        except ImportError:
            st.bar_chart(vw)


# ═══════════════════════════════════════════════════════════════════════════════
# PAGE: SUCHE STARTEN
# ═══════════════════════════════════════════════════════════════════════════════
elif page == "🔍 Suche starten":
    st.title("🔍 Suche starten")
    st.markdown(
        "Konfiguriere dein Suchgebiet und starte die Suche. "
        "Das Programm lädt alle Zwangsversteigerungen vom ZVG-Portal und speichert sie lokal."
    )

    cfg = load_config_yaml()
    area = cfg.get("scraper", {}).get("area_of_interest", {})

    with st.form("search_form"):
        bundesland = st.selectbox(
            "Bundesland",
            BUNDESLAENDER,
            index=BUNDESLAENDER.index(area.get("bundesland", "Bayern"))
            if area.get("bundesland") in BUNDESLAENDER else 1,
            help="Alle Angebote im gewählten Bundesland werden geladen.",
        )

        st.subheader("⚙️ Optionen")
        c1, c2, c3 = st.columns(3)
        do_download = c1.checkbox("PDFs + Fotos laden", value=True)
        do_analyse = c2.checkbox("KI-Analyse ausführen", value=True)
        do_drive = c3.checkbox("Google Drive sync", value=False)

        submitted = st.form_submit_button(
            "🚀 Suche starten", use_container_width=True, type="primary"
        )

    if submitted:
        cfg.setdefault("scraper", {}).setdefault("area_of_interest", {})
        cfg["scraper"]["area_of_interest"]["bundesland"] = bundesland
        cfg["scraper"]["area_of_interest"]["plz_range"] = []
        cfg["scraper"]["area_of_interest"]["amtsgerichte"] = []
        save_config_yaml(cfg)

        # Build CLI command
        cmd = [sys.executable, "-m", "src", "scrape", "--land", bundesland]
        if not do_download:
            cmd.append("--no-download")
        if not do_analyse:
            cmd.append("--no-analyse")
        if not do_drive:
            cmd.append("--no-drive")

        st.info(f"Starte: `{' '.join(cmd)}`")

        # Stream output
        log_area = st.empty()
        progress_bar = st.progress(0, text="Verbinde mit ZVG-Portal …")
        log_lines: list[str] = []

        def stream_output(proc, q: Queue):
            for line in iter(proc.stdout.readline, ""):
                q.put(line)
            q.put(None)  # sentinel

        with st.spinner("Suche läuft …"):
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(ROOT),
                env={**__import__("os").environ, "PYTHONUNBUFFERED": "1"},
            )
            q: Queue = Queue()
            t = threading.Thread(target=stream_output, args=(proc, q), daemon=True)
            t.start()

            step = 0
            while True:
                try:
                    line = q.get(timeout=0.1)
                    if line is None:
                        break
                    log_lines.append(line.rstrip())
                    log_area.code("\n".join(log_lines[-30:]), language="")
                    step = min(step + 1, 95)
                    progress_bar.progress(step, text=line.strip()[:80])
                except Empty:
                    time.sleep(0.05)

            proc.wait()
            t.join()

        if proc.returncode == 0:
            progress_bar.progress(100, text="✅ Fertig!")
            st.success("Suche abgeschlossen! Gehe zu **📋 Alle Objekte** oder **📊 Dashboard**.")
            st.balloons()
        else:
            progress_bar.progress(100, text="❌ Fehler")
            st.error(
                "Fehler beim Ausführen. Prüfe die Ausgabe oben. "
                "Häufige Ursachen: kein Internet, falsches Bundesland, fehlender API-Key."
            )


# ═══════════════════════════════════════════════════════════════════════════════
# PAGE: ALLE OBJEKTE
# ═══════════════════════════════════════════════════════════════════════════════
elif page == "📋 Alle Objekte":
    st.title("📋 Alle Objekte")

    if not listings:
        st.info("Noch keine Daten. Gehe zu **🔍 Suche starten**.")
        st.stop()

    import pandas as pd

    df = pd.DataFrame(listings)

    # ── Filters ──
    with st.expander("🔎 Filter", expanded=True):
        fc1, fc2, fc3, fc4 = st.columns(4)

        status_filter = fc1.multiselect(
            "Status", ["active", "cancelled"], default=["active"]
        )
        bl_options = sorted(df["bundesland"].dropna().unique().tolist())
        bl_filter = fc2.multiselect("Bundesland", bl_options, default=bl_options)

        _vw_max = df["verkehrswert"].dropna().max()
        vw_max = int(_vw_max) if _vw_max == _vw_max else 1_000_000  # guard against NaN
        vw_range = fc3.slider(
            "Verkehrswert (€)", 0, vw_max,
            (0, min(500_000, vw_max)),
            step=10_000,
            format="%d €",
        )
        score_min = fc4.slider("Min. AI-Score", 0, 10, 0)

    mask = (
        df["status"].isin(status_filter) &
        df["bundesland"].isin(bl_filter)
    )
    if df["verkehrswert"].notna().any():
        mask &= (
            df["verkehrswert"].isna() |
            ((df["verkehrswert"] >= vw_range[0]) & (df["verkehrswert"] <= vw_range[1]))
        )
    if score_min > 0:
        mask &= df["ai_attractiveness_score"].fillna(0) >= score_min

    filtered = df[mask]
    st.caption(f"{len(filtered)} Objekte gefunden")

    if filtered.empty:
        st.warning("Keine Objekte passen zu deinen Filtern.")
        st.stop()

    # ── Display columns ──
    display_cols = [
        "aktenzeichen", "amtsgericht", "bundesland",
        "termin", "plz", "ort", "objekt_beschreibung",
        "verkehrswert", "mindestgebot_50pct", "sicherheitsgrenze_70pct",
        "wohnflaeche_sqm", "baujahr", "price_per_sqm",
        "ai_attractiveness_score", "ai_risk_flags", "ai_summary",
        "status", "drive_folder_url",
    ]
    show_cols = [c for c in display_cols if c in filtered.columns]
    display_df = filtered[show_cols].copy()

    # Format money columns
    for col in ["verkehrswert", "mindestgebot_50pct", "sicherheitsgrenze_70pct"]:
        if col in display_df:
            display_df[col] = display_df[col].apply(
                lambda v: f"{v:,.0f} €".replace(",", ".") if v else "–"
            )

    st.dataframe(
        display_df,
        use_container_width=True,
        height=500,
        column_config={
            "aktenzeichen": st.column_config.TextColumn("Aktenzeichen", width="medium"),
            "amtsgericht": st.column_config.TextColumn("Amtsgericht"),
            "termin": st.column_config.TextColumn("Termin"),
            "objekt_beschreibung": st.column_config.TextColumn("Objekt", width="large"),
            "verkehrswert": st.column_config.TextColumn("Verkehrswert"),
            "mindestgebot_50pct": st.column_config.TextColumn("Mindestgebot (50%)"),
            "sicherheitsgrenze_70pct": st.column_config.TextColumn("Sicherheitsgrenze (70%)"),
            "wohnflaeche_sqm": st.column_config.NumberColumn("Wohnfl. m²", format="%.0f"),
            "baujahr": st.column_config.NumberColumn("Baujahr", format="%d"),
            "price_per_sqm": st.column_config.NumberColumn("€/m²", format="%.0f"),
            "ai_attractiveness_score": st.column_config.NumberColumn("Score", format="%d/10"),
            "ai_summary": st.column_config.TextColumn("KI-Zusammenfassung", width="large"),
            "ai_risk_flags": st.column_config.TextColumn("Risiken"),
            "drive_folder_url": st.column_config.LinkColumn("Drive"),
        },
    )

    # ── Detail view ──
    st.subheader("🔍 Objekt-Detail")
    az_list = filtered["aktenzeichen"].tolist()
    selected_az = st.selectbox("Aktenzeichen auswählen", az_list)
    if selected_az:
        row = filtered[filtered["aktenzeichen"] == selected_az].iloc[0]
        c1, c2 = st.columns(2)
        with c1:
            st.markdown(f"### {row['aktenzeichen']}")
            st.markdown(f"**Amtsgericht:** {row['amtsgericht']}")
            st.markdown(f"**Ort:** {row['plz']} {row['ort']}")
            st.markdown(f"**Termin:** {row.get('termin', '–')}")
            st.markdown(f"**Status:** {'✅ Aktiv' if row['status'] == 'active' else '❌ Aufgehoben'}")
            st.markdown("---")
            st.markdown(f"**Verkehrswert:** {fmt_eur(row.get('verkehrswert'))}")
            st.markdown(f"**Mindestgebot (50%):** {fmt_eur(row.get('mindestgebot_50pct'))}")
            st.markdown(f"**Sicherheitsgrenze (70%):** {fmt_eur(row.get('sicherheitsgrenze_70pct'))}")
            if row.get("drive_folder_url"):
                st.markdown(f"[📁 Google Drive Ordner öffnen]({row['drive_folder_url']})")
        with c2:
            st.markdown(f"**Wohnfläche:** {row.get('wohnflaeche_sqm') or '–'} m²")
            st.markdown(f"**Grundstück:** {row.get('grundstueck_sqm') or '–'} m²")
            st.markdown(f"**Baujahr:** {row.get('baujahr') or '–'}")
            st.markdown(f"**Zimmer:** {row.get('zimmer') or '–'}")
            st.markdown(f"**€/m²:** {fmt_eur(row.get('price_per_sqm'))}")
            st.markdown("---")
            score = row.get("ai_attractiveness_score")
            if score:
                color = score_color(score)
                st.markdown(
                    f"**KI-Score:** <span style='color:{color};font-size:1.4em;"
                    f"font-weight:bold'>{score}/10</span>",
                    unsafe_allow_html=True,
                )
            if row.get("ai_recommended_max_bid"):
                st.markdown(f"**Empf. Max-Gebot:** {fmt_eur(row.get('ai_recommended_max_bid'))}")
            if row.get("ai_summary"):
                st.info(row["ai_summary"])
            if row.get("ai_risk_flags"):
                st.warning(f"⚠️ Risiken: {row['ai_risk_flags']}")

        st.markdown("**Objekt-Beschreibung:**")
        st.markdown(f"> {row.get('objekt_beschreibung', '–')}")

        # Documents & Photos
        _IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tif", ".tiff"}

        gutachten = row.get("gutachten_local_path")
        expose = row.get("expose_local_path")

        docs_to_show = []
        if gutachten and Path(gutachten).exists():
            docs_to_show.append(("Gutachten", gutachten))
        if expose and Path(expose).exists():
            docs_to_show.append(("Exposé", expose))

        if docs_to_show:
            st.markdown("**Dokumente:**")
            for label, path in docs_to_show:
                p = Path(path)
                if p.suffix.lower() in _IMAGE_EXTS:
                    st.image(str(p), caption=label, use_container_width=True)
                else:
                    with open(path, "rb") as f:
                        st.download_button(
                            f"📄 {label} herunterladen",
                            f,
                            file_name=p.name,
                            mime="application/pdf",
                        )

        # Fotos
        foto_paths_raw = row.get("foto_local_paths") or row.get("foto_local_path") or ""
        if isinstance(foto_paths_raw, str):
            import json as _json
            try:
                foto_paths = _json.loads(foto_paths_raw)
            except Exception:
                foto_paths = [foto_paths_raw] if foto_paths_raw else []
        else:
            foto_paths = list(foto_paths_raw)

        existing_fotos = [p for p in foto_paths if Path(p).exists()]
        if existing_fotos:
            st.markdown("**Fotos:**")
            cols = st.columns(min(3, len(existing_fotos)))
            for i, fp in enumerate(existing_fotos):
                p = Path(fp)
                if p.suffix.lower() in _IMAGE_EXTS:
                    cols[i % 3].image(str(p), use_container_width=True)
                else:
                    with open(fp, "rb") as f:
                        cols[i % 3].download_button(
                            f"📥 Foto {i+1}",
                            f,
                            file_name=p.name,
                        )


# ═══════════════════════════════════════════════════════════════════════════════
# PAGE: EINSTELLUNGEN
# ═══════════════════════════════════════════════════════════════════════════════
elif page == "⚙️ Einstellungen":
    st.title("⚙️ Einstellungen")

    cfg = load_config_yaml()
    env = load_env()

    # ── KI-Provider ──
    with st.expander("🤖 KI-Analyse", expanded=True):
        ai_provider = st.selectbox(
            "KI-Provider",
            ["claude", "ollama", "openrouter"],
            index=["claude", "ollama", "openrouter"].index(
                cfg.get("analysis", {}).get("ai_provider", "claude")
            ),
            help=(
                "claude = Anthropic API (beste Qualität, kostenpflichtig) | "
                "ollama = lokal & kostenlos | "
                "openrouter = günstige Cloud-Modelle"
            ),
        )

        if ai_provider == "claude":
            st.markdown(
                "API-Key unter [console.anthropic.com](https://console.anthropic.com). "
                "**Haiku** ist ~20× günstiger als Opus und reicht für die meisten Analysen."
            )
            anthropic_key = st.text_input(
                "Anthropic API-Key",
                value=env.get("ANTHROPIC_API_KEY", ""),
                type="password",
                placeholder="sk-ant-...",
            )
            openrouter_key = env.get("OPENROUTER_API_KEY", "")
            claude_model = st.selectbox(
                "Claude-Modell",
                ["claude-haiku-4-5-20251001", "claude-sonnet-4-6", "claude-opus-4-6"],
                index=["claude-haiku-4-5-20251001", "claude-sonnet-4-6", "claude-opus-4-6"].index(
                    cfg.get("analysis", {}).get("ai_model", "claude-haiku-4-5-20251001")
                ),
                help="Haiku: günstig & schnell | Sonnet: ausgewogen | Opus: Premium",
            )
            ollama_model = cfg.get("analysis", {}).get("ollama_model", "llama3.2")
            ollama_endpoint = cfg.get("analysis", {}).get("ollama_endpoint", "http://localhost:11434")

        elif ai_provider == "ollama":
            st.markdown(
                "Ollama läuft lokal — **komplett kostenlos**. "
                "Installation: [ollama.com](https://ollama.com) → `ollama pull llama3.2`"
            )
            ollama_endpoint = st.text_input(
                "Ollama Endpoint",
                value=cfg.get("analysis", {}).get("ollama_endpoint", "http://localhost:11434"),
                placeholder="http://localhost:11434",
            )
            ollama_model = st.text_input(
                "Ollama Modell",
                value=cfg.get("analysis", {}).get("ollama_model", "llama3.2"),
                placeholder="llama3.2",
                help="Verfügbare Modelle: llama3.2, mistral, qwen2.5, phi3",
            )
            anthropic_key = env.get("ANTHROPIC_API_KEY", "")
            openrouter_key = env.get("OPENROUTER_API_KEY", "")
            claude_model = cfg.get("analysis", {}).get("ai_model", "claude-haiku-4-5-20251001")

            # Verbindungstest
            if st.button("Ollama-Verbindung testen"):
                import requests as _req
                try:
                    r = _req.get(f"{ollama_endpoint}/api/tags", timeout=5)
                    models = [m["name"] for m in r.json().get("models", [])]
                    if models:
                        st.success(f"✅ Ollama erreichbar. Installierte Modelle: {', '.join(models)}")
                    else:
                        st.warning("Ollama erreichbar, aber keine Modelle installiert. Führe `ollama pull llama3.2` aus.")
                except Exception as e:
                    st.error(f"❌ Ollama nicht erreichbar: {e}. Starte Ollama mit `ollama serve`.")

        elif ai_provider == "openrouter":
            st.markdown(
                "OpenRouter bietet viele Modelle zu niedrigen Preisen. "
                "API-Key unter [openrouter.ai](https://openrouter.ai)."
            )
            openrouter_key = st.text_input(
                "OpenRouter API-Key",
                value=env.get("OPENROUTER_API_KEY", ""),
                type="password",
                placeholder="sk-or-...",
            )
            claude_model = st.text_input(
                "Modell (OpenRouter)",
                value=cfg.get("analysis", {}).get("ai_model", "mistralai/mistral-7b-instruct"),
                placeholder="mistralai/mistral-7b-instruct",
                help="Alle Modelle: openrouter.ai/models",
            )
            anthropic_key = env.get("ANTHROPIC_API_KEY", "")
            ollama_model = cfg.get("analysis", {}).get("ollama_model", "llama3.2")
            ollama_endpoint = cfg.get("analysis", {}).get("ollama_endpoint", "http://localhost:11434")

    # ── API Keys (legacy für nicht-claude Provider) ──
    with st.expander("🔑 API-Keys & Zugangsdaten", expanded=False):
        st.markdown("Hier kannst du zusätzliche API-Keys hinterlegen.")

    # ── Alerts ──
    with st.expander("🔔 Benachrichtigungen"):
        alert_channel = st.selectbox(
            "Kanal",
            ["none", "telegram", "email"],
            index=["none", "telegram", "email"].index(
                cfg.get("analysis", {}).get("alert_channel", "none")
            ),
        )
        alert_threshold = st.number_input(
            "Nur Objekte benachrichtigen bis Verkehrswert (€)",
            value=int(cfg.get("analysis", {}).get("alert_threshold_verkehrswert_max", 500000)),
            step=10000,
        )

        if alert_channel == "telegram":
            st.markdown(
                "Erstelle einen Bot über [@BotFather](https://t.me/botfather) auf Telegram."
            )
            tg_token = st.text_input(
                "Telegram Bot-Token",
                value=env.get("TELEGRAM_BOT_TOKEN", ""),
                type="password",
                placeholder="123456:ABC-DEF...",
            )
            tg_chat = st.text_input(
                "Telegram Chat-ID",
                value=env.get("TELEGRAM_CHAT_ID", ""),
                placeholder="123456789",
                help="Schreib deinem Bot eine Nachricht, dann /getUpdates aufrufen",
            )
        elif alert_channel == "email":
            em_from = st.text_input("Absender E-Mail", value=env.get("ALERT_EMAIL_FROM", ""))
            em_to = st.text_input("Empfänger E-Mail", value=env.get("ALERT_EMAIL_TO", ""))
            em_user = st.text_input("SMTP Benutzername", value=env.get("ALERT_EMAIL_SMTP_USER", ""))
            em_pass = st.text_input("SMTP Passwort", value=env.get("ALERT_EMAIL_SMTP_PASS", ""), type="password")

    # ── Schedule ──
    with st.expander("⏰ Automatischer Zeitplan"):
        st.markdown("Lasse die Suche täglich automatisch laufen (nur wenn das Programm läuft).")
        schedule_cron = st.text_input(
            "Cron-Ausdruck",
            value=cfg.get("scraper", {}).get("schedule_cron", "0 7 * * *"),
            help="Format: Minute Stunde Tag Monat Wochentag. '0 7 * * *' = täglich 07:00",
        )
        st.caption("Beispiele: `0 7 * * *` = täglich 7 Uhr | `0 8 * * 1` = montags 8 Uhr")

    # ── Lokaler Speicherort ──
    with st.expander("📁 Lokaler Speicherort", expanded=True):
        default_files_dir = str(
            cfg.get("storage", {}).get("files_dir", "")
            or Path.home() / "Downloads" / "ZVG"
        )
        files_dir_input = st.text_input(
            "Ordner für heruntergeladene Dateien (Gutachten, Fotos, ...)",
            value=default_files_dir,
            placeholder=str(Path.home() / "Downloads" / "ZVG"),
            help="Absoluter Pfad wo PDFs und Fotos gespeichert werden.",
        )
        if files_dir_input:
            resolved = Path(files_dir_input).expanduser()
            st.caption(f"Gespeichert in: `{resolved}`")

    # ── Google Drive ──
    with st.expander("☁️ Google Drive"):
        st.markdown(
            "**Option A — Eigenen Ordner per Link angeben** (empfohlen): "
            "Erstelle einen Ordner in deinem Google Drive, teile ihn mit "
            "deinem Service-Account (oder öffentlich), und füge den Link unten ein."
        )
        drive_folder_link = st.text_input(
            "Google Drive Ordner-Link",
            value=cfg.get("storage", {}).get("google_drive", {}).get("root_folder_link", ""),
            placeholder="https://drive.google.com/drive/folders/1abc...",
            help="Teile den Ordner zuerst mit deinem Service-Account oder mache ihn für alle bearbeitbar.",
        )

        st.markdown("---")
        st.markdown(
            "**Option B — Neuen Ordner anlegen**: Gib einen Namen an, "
            "der Ordner wird automatisch in deinem Drive erstellt."
        )
        drive_folder = st.text_input(
            "Drive-Ordnername (wird neu erstellt)",
            value=cfg.get("storage", {}).get("google_drive", {}).get("root_folder_name", "ZVG_Data"),
            help="Wird ignoriert wenn ein Ordner-Link angegeben ist.",
        )

        st.markdown("---")
        st.markdown(
            "Lade `credentials.json` von der "
            "[Google Cloud Console](https://console.cloud.google.com) herunter "
            "(Drive API aktivieren → OAuth2-Zugangsdaten erstellen)."
        )
        uploaded_creds = st.file_uploader(
            "credentials.json hochladen",
            type=["json"],
            help="OAuth2 oder Service-Account JSON von Google Cloud",
        )
        if uploaded_creds:
            SECRETS_DIR.mkdir(exist_ok=True)
            (SECRETS_DIR / "gdrive_credentials.json").write_bytes(uploaded_creds.read())
            st.success("✅ Zugangsdaten gespeichert!")

    # ── Save button ──
    if st.button("💾 Einstellungen speichern", type="primary", use_container_width=True):
        # Save .env
        new_env = {
            **env,
            "ANTHROPIC_API_KEY": anthropic_key,
            "OPENROUTER_API_KEY": openrouter_key,
        }
        if alert_channel == "telegram":
            new_env["TELEGRAM_BOT_TOKEN"] = tg_token
            new_env["TELEGRAM_CHAT_ID"] = tg_chat
        elif alert_channel == "email":
            new_env["ALERT_EMAIL_FROM"] = em_from
            new_env["ALERT_EMAIL_TO"] = em_to
            new_env["ALERT_EMAIL_SMTP_USER"] = em_user
            new_env["ALERT_EMAIL_SMTP_PASS"] = em_pass
        save_env(new_env)

        # Save config.yaml
        cfg.setdefault("scraper", {})["schedule_cron"] = schedule_cron
        analysis_cfg = cfg.setdefault("analysis", {})
        analysis_cfg["alert_channel"] = alert_channel
        analysis_cfg["alert_threshold_verkehrswert_max"] = alert_threshold
        analysis_cfg["ai_provider"] = ai_provider
        analysis_cfg["ai_model"] = claude_model
        analysis_cfg["ollama_model"] = ollama_model
        analysis_cfg["ollama_endpoint"] = ollama_endpoint
        storage_cfg = cfg.setdefault("storage", {})
        if files_dir_input:
            storage_cfg["files_dir"] = str(Path(files_dir_input).expanduser())
        drive_cfg = storage_cfg.setdefault("google_drive", {})
        drive_cfg["root_folder_name"] = drive_folder
        drive_cfg["root_folder_link"] = drive_folder_link
        save_config_yaml(cfg)

        st.success("✅ Einstellungen gespeichert!")

    st.markdown("---")

    # ── Danger zone ──
    with st.expander("🗑️ Daten zurücksetzen"):
        st.warning("Diese Aktionen können nicht rückgängig gemacht werden.")
        if st.button("Datenbank leeren", type="secondary"):
            if DB_PATH.exists():
                DB_PATH.unlink()
                st.success("Datenbank gelöscht.")
                st.rerun()
