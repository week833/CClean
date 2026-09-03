"""Row builders shared by the test modules."""

from __future__ import annotations

from typing import Any

from dstock_canon.canonical import build_row

PRICE_VALUES = {
    "open": 580, "high": 585, "low": 578, "close": 584, "change": 4,
    "volume_shares": 31245000, "turnover_value": 18200000000,
    "transaction_count": 42137, "limit_up": 638, "limit_down": 522,
}


def price_row(
    stock_id: str = "2330",
    row_date: str = "2026-09-03",
    *,
    source_id: str = "market_update",
    source_class: str = "primary",
    close: Any = 584,
    availability_basis: str = "vendor_publish",
    availability_time: str | None = "2026-09-03T14:30:00+08:00",
    market: str = "twse",
    unit_basis: str = "shares",
    price_basis: str = "raw",
    adj_snapshot_id: str | None = None,
    ingested_at: str = "2026-09-03T15:02:11+08:00",
    quarantined: bool = False,
) -> dict[str, Any]:
    values = dict(PRICE_VALUES, close=close)
    return build_row(
        dataset="daily_price",
        key_values={"stock_id": stock_id, "date": row_date},
        values=values,
        row_date=row_date,
        source_id=source_id,
        source_class=source_class,
        ingested_at=ingested_at,
        availability_basis=availability_basis,
        availability_time=availability_time,
        market=market,
        unit_basis=unit_basis,
        price_basis=price_basis,
        adj_snapshot_id=adj_snapshot_id,
        quarantined=quarantined,
    )


def revenue_row(stock_id: str = "2330", year: int = 2026, month: int = 8, revenue: int = 1234567) -> dict[str, Any]:
    return build_row(
        dataset="month_revenue",
        key_values={"stock_id": stock_id, "revenue_year": year, "revenue_month": month},
        values={"revenue": revenue, "currency": "TWD"},
        row_date="2026-09-03",
        source_id="finmind_collect",
        source_class="backup",
        ingested_at="2026-09-03T15:02:11+08:00",
        availability_basis="conservative_lag",
        availability_time="2026-09-13T00:00:00+08:00",
    )
