from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def submit_assignment(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST only"}, status=405)

    file = request.FILES.get("file")
    if not file:
        return JsonResponse({"error": "no file"}, status=400)

    return JsonResponse({
        "status": "ok",
        "filename": file.name,
    })
