#!/usr/bin/env python3
"""Сгенерировать видео из input.jpg через Replicate (MiniMax Video-01)."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent
INPUT_IMAGE = ROOT / "input.jpg"
OUTPUT_VIDEO = ROOT / "output.video.mp4"
MODEL = "minimax/video-01"
PROMPT = "Smooth natural motion, high cinematic quality, dynamic light"


def fail(message: str) -> None:
    print(f"Ошибка: {message}", file=sys.stderr)
    raise SystemExit(1)


def video_url(output: object) -> str:
    """Достать HTTPS-ссылку из ответа replicate.run."""
    if isinstance(output, (list, tuple)):
        if not output:
            fail("модель вернула пустой результат.")
        output = output[0]

    if isinstance(output, str):
        url = output
    else:
        url = getattr(output, "url", None)

    if isinstance(url, str) and url.startswith(("http://", "https://")):
        return url

    fail(f"не удалось получить ссылку на видео. Ответ модели: {output!r}")
    return ""  # unreachable; keeps the type checker quiet


def download(url: str, destination: Path) -> None:
    partial = destination.with_name(destination.name + ".part")
    try:
        with requests.get(url, stream=True, timeout=300) as response:
            response.raise_for_status()
            with partial.open("wb") as file:
                for chunk in response.iter_content(chunk_size=256 * 1024):
                    if chunk:
                        file.write(chunk)
        partial.replace(destination)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise


def main() -> None:
    token = os.environ.get("REPLICATE_API_TOKEN", "").strip()
    if not token:
        fail(
            "не указан API-ключ. Задайте переменную окружения REPLICATE_API_TOKEN "
            "(токен берётся на https://replicate.com/account/api-tokens)."
        )

    if not INPUT_IMAGE.is_file():
        fail(f"нет файла изображения: {INPUT_IMAGE.name} (положите его в корень проекта).")

    if INPUT_IMAGE.stat().st_size == 0:
        fail(f"файл {INPUT_IMAGE.name} пустой.")

    try:
        import replicate
    except ImportError:
        fail("не установлен пакет replicate. Выполните: pip install replicate")

    print(f"Модель: {MODEL}")
    print("Загрузка изображения и ожидание генерации. Это может занять несколько минут...")

    try:
        with INPUT_IMAGE.open("rb") as image_file:
            # replicate.run блокирует выполнение, пока предсказание не завершится.
            output = replicate.run(
                MODEL,
                input={
                    "prompt": PROMPT,
                    "first_frame_image": image_file,
                    "prompt_optimizer": True,
                },
            )
    except replicate.exceptions.ReplicateError as exc:
        fail(f"Replicate отклонил запрос: {exc}")

    url = video_url(output)
    print(f"Видео готово, скачиваю: {url}")

    try:
        download(url, OUTPUT_VIDEO)
    except requests.RequestException as exc:
        fail(f"не удалось скачать видео: {exc}")
    except OSError as exc:
        fail(f"не удалось сохранить файл: {exc}")

    print(f"Сохранено: {OUTPUT_VIDEO}")


if __name__ == "__main__":
    main()
