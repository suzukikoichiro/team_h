from django.http import JsonResponse
from django.views.decorators.http import require_POST

from ..decorators import api_user_required

MAX_ASSIGNMENT_SIZE = 10 * 1024 * 1024
ALLOWED_ASSIGNMENT_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".txt", ".zip"}

@api_user_required
@require_POST
def submit_assignment(request):
    file = request.FILES.get("file")
    if not file:
        return JsonResponse({"error": "no file"}, status=400)
    suffix = "." + file.name.rsplit(".", 1)[-1].lower() if "." in file.name else ""
    if suffix not in ALLOWED_ASSIGNMENT_EXTENSIONS:
        return JsonResponse({"error": "unsupported_file_type"}, status=400)
    if file.size > MAX_ASSIGNMENT_SIZE:
        return JsonResponse({"error": "file_too_large", "max_bytes": MAX_ASSIGNMENT_SIZE}, status=400)

    return JsonResponse({
        "status": "ok",
        "filename": file.name,
        "size": file.size,
    })
