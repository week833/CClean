"""Versioned dataset contract shared by central market_update and the collect tool.

Both sides MUST import this module rather than restating join keys, field
whitelists or decimal places locally. Any change to a spec is a contract change
and requires bumping SCHEMA_VERSION.
"""

from __future__ import annotations

from dataclasses import dataclass, field


SCHEMA_NAME = "dstock.market.canonical"
SCHEMA_VERSION = 1

KEY_SEPARATOR = "|"

SOURCE_CLASSES = ("primary", "backup", "reference_only")
SOURCE_IDS = ("market_update", "finmind_collect", "mitake_ui")
AVAILABILITY_BASES = ("announced", "created", "vendor_publish", "conservative_lag", "unknown")
MARKETS = ("twse", "tpex", "emerging", "not_applicable", "unknown")
UNIT_BASES = ("shares", "lots", "not_applicable", "unknown")
PRICE_BASES = ("raw", "adjusted", "not_applicable")

# availability_basis ranked best first; used by the precedence rule.
AVAILABILITY_RANK = {
    "announced": 0,
    "created": 1,
    "vendor_publish": 2,
    "conservative_lag": 3,
    "unknown": 4,
}

SOURCE_CLASS_RANK = {"primary": 0, "backup": 1, "reference_only": 2}


class SpecError(ValueError):
    """Raised when a dataset or field is not part of the declared contract."""


@dataclass(frozen=True)
class FieldSpec:
    """One business field inside a canonical row's ``values``.

    ``places`` is the decimal quantization used by the shared value hash. It is
    ignored for ``text`` and ``bool`` fields.
    """

    name: str
    kind: str  # decimal | integer | text | bool
    places: int = 0

    def __post_init__(self) -> None:
        if self.kind not in ("decimal", "integer", "text", "bool"):
            raise SpecError(f"未知的欄位型別: {self.kind}")
        if self.places < 0:
            raise SpecError(f"小數位不可為負: {self.name}")


@dataclass(frozen=True)
class DatasetSpec:
    """Join key order plus the business-field whitelist for one logical table."""

    name: str
    key_fields: tuple[str, ...]
    fields: tuple[FieldSpec, ...]
    requires_market: bool = True
    requires_unit: bool = True
    requires_price_basis: bool = False
    notes: str = ""
    _by_name: dict[str, FieldSpec] = field(default_factory=dict, compare=False, repr=False)

    def __post_init__(self) -> None:
        if not self.key_fields:
            raise SpecError(f"{self.name} 必須宣告 key_fields")
        names = [f.name for f in self.fields]
        if len(names) != len(set(names)):
            raise SpecError(f"{self.name} 的欄位名稱重複")
        object.__setattr__(self, "_by_name", {f.name: f for f in self.fields})

    def field_spec(self, name: str) -> FieldSpec:
        try:
            return self._by_name[name]
        except KeyError:
            raise SpecError(f"{self.name} 不含欄位 {name}；欄位白名單是契約的一部分") from None

    def field_names(self) -> tuple[str, ...]:
        return tuple(f.name for f in self.fields)


def _d(name: str, places: int) -> FieldSpec:
    return FieldSpec(name, "decimal", places)


def _i(name: str) -> FieldSpec:
    return FieldSpec(name, "integer")


def _t(name: str) -> FieldSpec:
    return FieldSpec(name, "text")


def _b(name: str) -> FieldSpec:
    return FieldSpec(name, "bool")


DATASET_SPECS: dict[str, DatasetSpec] = {
    spec.name: spec
    for spec in (
        DatasetSpec(
            name="daily_price",
            key_fields=("stock_id", "date"),
            fields=(
                _d("open", 4), _d("high", 4), _d("low", 4), _d("close", 4), _d("change", 4),
                _i("volume_shares"), _d("turnover_value", 4), _i("transaction_count"),
                _d("limit_up", 4), _d("limit_down", 4),
            ),
            requires_price_basis=True,
            notes="raw 與 adjusted 不得混入同一序列；limit 為 0 可能表示無漲跌幅限制，不是缺值。",
        ),
        DatasetSpec(
            name="institutional_investors",
            key_fields=("stock_id", "date", "investor_name"),
            fields=(_i("buy_shares"), _i("sell_shares"), _i("net_shares")),
            notes="長表保留 investor_name；不可把不同法人列相加而遺失類別。",
        ),
        DatasetSpec(
            name="broker_branch",
            key_fields=("stock_id", "date", "securities_trader_id"),
            fields=(_i("buy_shares"), _i("sell_shares"), _d("buy_price", 4), _d("sell_price", 4)),
            notes="興櫃推薦券商的 price=0 仍可有買賣股數；不得當缺失或計入加權均價。",
        ),
        DatasetSpec(
            name="margin_short_sale",
            key_fields=("stock_id", "date"),
            fields=(
                _i("margin_balance"), _i("margin_buy"), _i("margin_sell"),
                _i("short_balance"), _i("short_buy"), _i("short_sell"), _i("offset_shares"),
            ),
        ),
        DatasetSpec(
            name="shareholding",
            key_fields=("stock_id", "date"),
            fields=(_i("foreign_shares"), _d("foreign_ratio", 6), _d("limit_ratio", 6)),
        ),
        DatasetSpec(
            name="month_revenue",
            key_fields=("stock_id", "revenue_year", "revenue_month"),
            fields=(_i("revenue"), _t("currency")),
            requires_market=False,
            requires_unit=False,
            notes="revenue_year/month 是營收期間；create_time 是入庫時間，不是公司公告時間。",
        ),
        DatasetSpec(
            name="financial_statements",
            key_fields=("stock_id", "date", "type"),
            fields=(_d("value", 4), _t("origin_name")),
            requires_market=False,
            requires_unit=False,
            notes="報告期間不等於公告可得時間；EPS 為單季值，跨季不可直接相加。",
        ),
        DatasetSpec(
            name="dividend_event",
            key_fields=("stock_id", "event_type", "event_date"),
            fields=(_d("cash_dividend", 6), _d("stock_dividend", 6), _t("announcement_date")),
            requires_market=False,
            requires_unit=False,
            notes="公告日、除權息交易日與支付日是不同事件，不可互相代替。",
        ),
        DatasetSpec(
            name="trading_calendar",
            key_fields=("market", "date"),
            fields=(_b("is_trading_day"),),
            requires_market=False,
            requires_unit=False,
            notes="coverage 分母的來源；不可用工作日推算交易日。",
        ),
        DatasetSpec(
            name="market_membership",
            key_fields=("stock_id", "valid_from"),
            fields=(_t("valid_to"), _t("market")),
            requires_market=False,
            requires_unit=False,
            notes="as-of 市場別的唯一依據；沒有對應觀察日的列即為 unknown，不得由最新列回推。",
        ),
    )
}


def get_spec(dataset: str) -> DatasetSpec:
    try:
        return DATASET_SPECS[dataset]
    except KeyError:
        known = ", ".join(sorted(DATASET_SPECS))
        raise SpecError(f"未註冊的 dataset: {dataset}；已註冊: {known}") from None


def dataset_names() -> tuple[str, ...]:
    return tuple(sorted(DATASET_SPECS))
