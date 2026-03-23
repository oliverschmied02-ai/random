"""
Send alerts for new high-value listings via email or Telegram.

A listing is considered "alert-worthy" when:
  - status == "active"
  - verkehrswert <= config.analysis.alert_threshold_verkehrswert_max
  - ai_attractiveness_score >= 7  (if AI analysis ran)
"""
from __future__ import annotations

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

from src.config import AppConfig
from src.models.listing import Listing

logger = logging.getLogger(__name__)


def send_alerts(new_listings: list[Listing], config: AppConfig) -> None:
    """Send alerts for interesting listings if a channel is configured."""
    channel = config.analysis.alert_channel
    if channel == "none" or not new_listings:
        return

    interesting = _filter_interesting(new_listings, config)
    if not interesting:
        logger.info("No alert-worthy listings found")
        return

    logger.info("Sending alerts for %d listings via %s", len(interesting), channel)

    if channel == "email":
        _send_email(interesting, config)
    elif channel == "telegram":
        _send_telegram(interesting, config)


def _filter_interesting(listings: list[Listing], config: AppConfig) -> list[Listing]:
    threshold = config.analysis.alert_threshold_verkehrswert_max
    result = []
    for l in listings:
        if l.status != "active":
            continue
        if l.verkehrswert and l.verkehrswert > threshold:
            continue
        if l.ai_attractiveness_score is not None and l.ai_attractiveness_score < 7:
            continue
        result.append(l)
    return result


# ---------------------------------------------------------------------------
# Email
# ---------------------------------------------------------------------------

def _send_email(listings: list[Listing], config: AppConfig) -> None:
    if not config.alert_email_from or not config.alert_email_to:
        logger.warning("Email credentials not configured — skipping email alert")
        return

    subject = f"ZVG Alert: {len(listings)} neue interessante Objekte"
    body = _build_email_body(listings)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = config.alert_email_from
    msg["To"] = config.alert_email_to
    msg.attach(MIMEText(body, "html", "utf-8"))

    try:
        with smtplib.SMTP(
            config.alert_email_smtp_host, config.alert_email_smtp_port
        ) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(config.alert_email_smtp_user, config.alert_email_smtp_pass)
            smtp.sendmail(
                config.alert_email_from,
                config.alert_email_to,
                msg.as_string(),
            )
        logger.info("Email alert sent to %s", config.alert_email_to)
    except Exception as exc:
        logger.error("Failed to send email alert: %s", exc)


def _build_email_body(listings: list[Listing]) -> str:
    items = ""
    for l in listings:
        drive = (
            f'<a href="{l.drive_folder_url}">📁 Drive-Ordner</a>'
            if l.drive_folder_url
            else ""
        )
        items += f"""
<div style="border:1px solid #ddd;border-radius:8px;padding:16px;margin-bottom:16px;">
  <h3 style="margin:0 0 8px">{l.aktenzeichen} — {l.amtsgericht}</h3>
  <p><b>Termin:</b> {l.termin.strftime("%d.%m.%Y %H:%M") if l.termin else "–"} |
     <b>Ort:</b> {l.plz} {l.ort}</p>
  <p><b>Verkehrswert:</b> {f"{l.verkehrswert:,.0f} €" if l.verkehrswert else "–"} |
     <b>Mindestgebot:</b> {f"{l.mindestgebot_50pct:,.0f} €" if l.mindestgebot_50pct else "–"}</p>
  <p><b>Score:</b> {l.ai_attractiveness_score or "–"}/10 |
     <b>Empf. Max-Gebot:</b> {f"{l.ai_recommended_max_bid:,.0f} €" if l.ai_recommended_max_bid else "–"}</p>
  <p><b>Zusammenfassung:</b> {l.ai_summary or "–"}</p>
  <p><b>Risiken:</b> {"; ".join(l.ai_risk_flags) or "keine"}</p>
  {drive}
</div>"""

    return f"""
<html><body>
<h2>🏠 ZVG Intelligence Alert</h2>
<p>{len(listings)} neue interessante Zwangsversteigerungen gefunden:</p>
{items}
<p style="color:#999;font-size:.85em">
  Generiert von ZVG Intelligence Platform
</p>
</body></html>"""


# ---------------------------------------------------------------------------
# Telegram
# ---------------------------------------------------------------------------

def _send_telegram(listings: list[Listing], config: AppConfig) -> None:
    if not config.telegram_bot_token or not config.telegram_chat_id:
        logger.warning("Telegram credentials not configured — skipping Telegram alert")
        return

    import requests as req

    for l in listings:
        text = (
            f"🏠 *Neue ZVG: {l.aktenzeichen}*\n"
            f"📍 {l.plz} {l.ort} | {l.amtsgericht}\n"
            f"📅 Termin: {l.termin.strftime('%d.%m.%Y') if l.termin else '–'}\n"
            f"💶 Verkehrswert: {f'{l.verkehrswert:,.0f} €' if l.verkehrswert else '–'}\n"
            f"🔑 Mindestgebot: {f'{l.mindestgebot_50pct:,.0f} €' if l.mindestgebot_50pct else '–'}\n"
            f"⭐ Score: {l.ai_attractiveness_score or '–'}/10\n"
        )
        if l.drive_folder_url:
            text += f"📁 [Drive]({l.drive_folder_url})"

        url = f"https://api.telegram.org/bot{config.telegram_bot_token}/sendMessage"
        try:
            resp = req.post(
                url,
                json={
                    "chat_id": config.telegram_chat_id,
                    "text": text,
                    "parse_mode": "Markdown",
                    "disable_web_page_preview": True,
                },
                timeout=10,
            )
            resp.raise_for_status()
            logger.info("Telegram alert sent for %s", l.aktenzeichen)
        except Exception as exc:
            logger.error("Telegram alert failed for %s: %s", l.aktenzeichen, exc)
