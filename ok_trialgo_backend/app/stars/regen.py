# =============================================================
# FICHIER : app/stars/regen.py
# ROLE    : Logique pure de regen des etoiles (1/5min, plafond)
# =============================================================
#
# Algorithme (memes principes que refill vies) :
#   delta = floor((now - stars_last_regen) / 5min)
#   new_stars = min(stars + delta, stars_max)
#   new_last  = stars_last_regen + actually_added * 5min
#
# PURE : pas d'IO. Testable a part.
# =============================================================

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


# Constante metier : 1 etoile toutes les 5 minutes (cf Supabase).
STAR_REGEN_INTERVAL = timedelta(minutes=5)


@dataclass(frozen=True)
class RegenResult:
    new_stars: int
    new_last_regen: datetime
    stars_added: int
    seconds_to_next_star: int | None


def apply_regen(
    *,
    current_stars: int,
    stars_max: int,
    last_regen: datetime,
    now: datetime | None = None,
) -> RegenResult:
    """Applique la regen sur un wallet et retourne le nouvel etat."""
    if now is None:
        now = datetime.now(timezone.utc)

    if current_stars >= stars_max:
        return RegenResult(
            new_stars=current_stars,
            new_last_regen=last_regen,
            stars_added=0,
            seconds_to_next_star=None,
        )

    elapsed = now - last_regen
    if elapsed.total_seconds() <= 0:
        return RegenResult(
            new_stars=current_stars,
            new_last_regen=last_regen,
            stars_added=0,
            seconds_to_next_star=int(STAR_REGEN_INTERVAL.total_seconds()),
        )
    delta = int(elapsed // STAR_REGEN_INTERVAL)
    if delta == 0:
        seconds_done = int(elapsed.total_seconds())
        return RegenResult(
            new_stars=current_stars,
            new_last_regen=last_regen,
            stars_added=0,
            seconds_to_next_star=max(
                0,
                int(STAR_REGEN_INTERVAL.total_seconds()) - seconds_done,
            ),
        )

    new_stars = min(current_stars + delta, stars_max)
    actually_added = new_stars - current_stars
    new_last = last_regen + STAR_REGEN_INTERVAL * actually_added

    if new_stars < stars_max:
        elapsed_since_new = now - new_last
        seconds_done = int(elapsed_since_new.total_seconds())
        next_in = max(
            0,
            int(STAR_REGEN_INTERVAL.total_seconds()) - seconds_done,
        )
    else:
        next_in = None

    return RegenResult(
        new_stars=new_stars,
        new_last_regen=new_last,
        stars_added=actually_added,
        seconds_to_next_star=next_in,
    )
