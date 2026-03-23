"""
Playwright-based session manager for zvg-portal.de.

The ZVG portal uses PHP session cookies and form-based navigation.
A real browser context (Playwright) is the most reliable approach.
"""
from __future__ import annotations

import asyncio
import time
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from playwright.async_api import (
    Browser,
    BrowserContext,
    Page,
    Playwright,
    async_playwright,
)
from tenacity import retry, stop_after_attempt, wait_exponential

from src.config import ScraperConfig

ZVG_BASE_URL = "https://www.zvg-portal.de"
ZVG_SEARCH_URL = f"{ZVG_BASE_URL}/index.php?button=Termine+suchen"


class ZVGSession:
    """
    Manages a single Playwright browser session for the ZVG portal.

    Usage:
        async with ZVGSession(config) as session:
            page = await session.new_page()
            ...
    """

    def __init__(self, config: ScraperConfig) -> None:
        self._config = config
        self._playwright: Playwright | None = None
        self._browser: Browser | None = None
        self._context: BrowserContext | None = None

    async def __aenter__(self) -> "ZVGSession":
        self._playwright = await async_playwright().start()
        self._browser = await self._playwright.chromium.launch(
            headless=self._config.headless,
            args=["--no-sandbox", "--disable-setuid-sandbox"],
        )
        self._context = await self._browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="de-DE",
            timezone_id="Europe/Berlin",
        )
        return self

    async def __aexit__(self, *_: object) -> None:
        if self._context:
            await self._context.close()
        if self._browser:
            await self._browser.close()
        if self._playwright:
            await self._playwright.stop()

    async def new_page(self) -> Page:
        assert self._context is not None, "Session not started"
        return await self._context.new_page()

    async def rate_limit(self) -> None:
        """Honour configured rate limit between requests."""
        await asyncio.sleep(self._config.rate_limit_seconds)
