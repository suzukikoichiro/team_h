import secrets
import time

from django.conf import settings
from django.core.mail import send_mail
from django.utils.crypto import constant_time_compare, salted_hmac


OTP_LENGTH = 6
OTP_TTL_SECONDS = 10 * 60
OTP_RESEND_COOLDOWN_SECONDS = 60
OTP_MAX_ATTEMPTS = 5


def normalize_email(value):
    return (value or "").strip().lower()


def mask_email(email):
    normalized = normalize_email(email)
    if "@" not in normalized:
        return ""
    local, domain = normalized.split("@", 1)
    visible = local[:2] if len(local) > 2 else local[:1]
    return f"{visible}{'*' * max(1, len(local) - len(visible))}@{domain}"


def _digest(code):
    return salted_hmac("core.email_otp", str(code)).hexdigest()


def issue_otp(request, purpose, email, *, force=False):
    now = int(time.time())
    existing = request.session.get(_session_key(purpose), {})
    if (
        not force
        and existing
        and normalize_email(existing.get("email")) == normalize_email(email)
        and now - int(existing.get("sent_at", 0)) < OTP_RESEND_COOLDOWN_SECONDS
    ):
        return False, "認証コードの再送信は60秒後に行えます。"

    code = f"{secrets.randbelow(10 ** OTP_LENGTH):0{OTP_LENGTH}d}"
    request.session[_session_key(purpose)] = {
        "email": normalize_email(email),
        "digest": _digest(code),
        "expires_at": now + OTP_TTL_SECONDS,
        "sent_at": now,
        "attempts": 0,
    }
    request.session.modified = True
    try:
        send_mail(
            "【2Dメタバース】メール認証コード",
            f"認証コードは {code} です。\n有効期限は10分です。\n心当たりがない場合は、このメールを破棄してください。",
            settings.DEFAULT_FROM_EMAIL,
            [normalize_email(email)],
            fail_silently=False,
        )
    except Exception:
        request.session.pop(_session_key(purpose), None)
        return False, "認証メールを送信できませんでした。メール設定を確認してください。"
    return True, "認証コードをメールで送信しました。"


def verify_otp(request, purpose, code, expected_email):
    key = _session_key(purpose)
    state = request.session.get(key)
    if not state or normalize_email(state.get("email")) != normalize_email(expected_email):
        return False, "認証手続きを最初からやり直してください。"
    if int(time.time()) > int(state.get("expires_at", 0)):
        request.session.pop(key, None)
        return False, "認証コードの有効期限が切れました。再送信してください。"
    attempts = int(state.get("attempts", 0)) + 1
    state["attempts"] = attempts
    request.session[key] = state
    request.session.modified = True
    if attempts > OTP_MAX_ATTEMPTS:
        request.session.pop(key, None)
        return False, "入力回数の上限を超えました。認証手続きをやり直してください。"
    if not constant_time_compare(state.get("digest", ""), _digest(code)):
        return False, "認証コードが違います。"
    request.session.pop(key, None)
    request.session.modified = True
    return True, "メールアドレスを確認しました。"


def clear_otp(request, purpose):
    request.session.pop(_session_key(purpose), None)


def _session_key(purpose):
    return f"email_otp:{purpose}"
