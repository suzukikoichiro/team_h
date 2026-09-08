from datetime import date

from django.db.models import Sum, Count
from django.utils import timezone

from .models import GrowthPointEvent, StudentUser


POINTS = {
    "login": 5,
    "chat_person": 8,
    "lesson_recording_view": 12,
    "lesson_live_join": 15,
}

# Activity never determines whether a plant reaches its next growth image.
# These thresholds only add a modest visual size boost to the shared plant.
SIZE_THRESHOLDS = [0, 50, 150, 300, 500]
MIN_PLANT_SCALE = 0.72
MAX_PLANT_SCALE = 1.02

SEASONS = [
    {"id": "spring", "label": "春", "months": [3, 4, 5], "plant_name": "いちごの苗"},
    {"id": "summer", "label": "夏", "months": [6, 7, 8], "plant_name": "ひまわり"},
    {"id": "autumn", "label": "秋", "months": [9, 10, 11], "plant_name": "りんごの木"},
    {"id": "winter", "label": "冬", "months": [12, 1, 2], "plant_name": "みかんの木"},
]


def current_season(now=None):
    now = now or timezone.localtime()
    month = now.month
    for season in SEASONS:
        if month in season["months"]:
            return season
    return SEASONS[0]


def current_season_key(now=None):
    now = now or timezone.localtime()
    season = current_season(now)
    year = now.year
    if season["id"] == "winter" and now.month in (1, 2):
        year -= 1
    return f"{year}-{season['id']}"


def current_season_range(now=None):
    now = now or timezone.localtime()
    season = current_season(now)
    year = now.year
    if season["id"] == "spring":
        start_month, end_month, end_year = 3, 5, year
    elif season["id"] == "summer":
        start_month, end_month, end_year = 6, 8, year
    elif season["id"] == "autumn":
        start_month, end_month, end_year = 9, 11, year
    else:
        start_month = 12
        if now.month in (1, 2):
            year -= 1
        end_month, end_year = 2, year + 1
    return {
        "start": f"{year:04d}-{start_month:02d}-01",
        "end": f"{end_year:04d}-{end_month:02d}",
    }


def current_season_dates(now=None):
    """Return the inclusive start date and exclusive end date for this season."""
    now = now or timezone.localtime()
    season = current_season(now)
    year = now.year
    if season["id"] == "spring":
        return date(year, 3, 1), date(year, 6, 1)
    if season["id"] == "summer":
        return date(year, 6, 1), date(year, 9, 1)
    if season["id"] == "autumn":
        return date(year, 9, 1), date(year, 12, 1)
    if now.month in (1, 2):
        year -= 1
    return date(year, 12, 1), date(year + 1, 3, 1)


def is_student_user(school, user_id):
    return StudentUser.objects.filter(school=school, user_id=user_id).exists()


def award_growth_points(school, user_id, event_type, event_key, points=None):
    if school is None or not user_id or not is_student_user(school, user_id):
        return None, False
    point_value = POINTS.get(event_type, 0) if points is None else int(points)
    if point_value <= 0:
        return None, False
    event, created = GrowthPointEvent.objects.get_or_create(
        school=school,
        user_id=user_id,
        event_type=event_type,
        event_key=str(event_key)[:120],
        defaults={
            "points": point_value,
            "season_key": current_season_key(),
        },
    )
    return event, created


def stage_for_season_time(now=None):
    """Advance the plant through all images over the three-month season."""
    now = now or timezone.localtime()
    start, end = current_season_dates(now)
    total_days = max((end - start).days, 1)
    elapsed_days = min(max((now.date() - start).days, 0), total_days - 1)
    return min((elapsed_days * len(SIZE_THRESHOLDS)) // total_days, len(SIZE_THRESHOLDS) - 1)


def plant_scale_for_points(total_points):
    size_step = 0
    for index, threshold in enumerate(SIZE_THRESHOLDS):
        if total_points >= threshold:
            size_step = index
    ratio = float(size_step) / float(max(len(SIZE_THRESHOLDS) - 1, 1))
    return round(MIN_PLANT_SCALE + (MAX_PLANT_SCALE - MIN_PLANT_SCALE) * ratio, 3)


def growth_summary_for_school(school):
    season = current_season()
    season_key = current_season_key()
    qs = GrowthPointEvent.objects.filter(school=school, season_key=season_key)
    total_points = qs.aggregate(total=Sum("points")).get("total") or 0
    user_points = (
        qs.values("user_id")
        .annotate(points=Sum("points"), events=Count("id"))
        .order_by("-points", "user_id")[:10]
    )
    by_type = {
        item["event_type"]: item["points"]
        for item in qs.values("event_type").annotate(points=Sum("points"))
    }
    return {
        "season_key": season_key,
        "season_id": season["id"],
        "season_label": season["label"],
        "season_range": current_season_range(),
        "plant_name": season["plant_name"],
        "total_points": total_points,
        # The plant's life cycle is calendar-driven, so it always fully grows.
        "stage": stage_for_season_time(),
        "max_stage": len(SIZE_THRESHOLDS) - 1,
        "plant_scale": plant_scale_for_points(total_points),
        "by_type": by_type,
        "top_users": list(user_points),
    }
