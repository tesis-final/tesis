"""Cliente del LLM (DEC-24: Groq, API compatible con OpenAI). Proveedor intercambiable
por configuración (LLM_API_URL, LLM_MODEL, LLM_API_KEY) sin tocar código."""

from __future__ import annotations

import re

import httpx

from app.config import Config
from app.llm.prompts import mensajes

_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")
# Cédula uruguaya con o sin puntos y guion (1.234.567-8, 4.567.890-1, 12345678).
_CEDULA = re.compile(r"(?<![\w.])\d{1,2}\.?\d{3}\.?\d{3}-?\d(?![\w])")


class LLMNoDisponible(Exception):
    """El proveedor no respondió o no está configurado (RNF-15: ATLAS sigue sin él)."""


class ClienteLLM:
    def __init__(self, config: Config, transporte: httpx.BaseTransport | None = None):
        self.config = config
        self.transporte = transporte

    def redactar(self, tipo: str, pregunta: str, contexto: dict) -> dict:
        if not self.config.llm_api_key:
            raise LLMNoDisponible("LLM_API_KEY no configurada")
        cuerpo = {
            "model": self.config.llm_model,
            "messages": mensajes(tipo, pregunta, contexto),
            "temperature": 0.2,
            "max_tokens": 400,
        }
        # Última barrera del lado del servicio: nunca sale un correo ni una cédula (H28).
        texto = str(cuerpo)
        if _EMAIL.search(texto) or _CEDULA.search(texto):
            raise ValueError("El contexto contiene un dato identificable (correo o cédula); no se envía")
        try:
            with httpx.Client(timeout=self.config.llm_timeout, transport=self.transporte) as http:
                r = http.post(
                    f"{self.config.llm_api_url.rstrip('/')}/chat/completions",
                    headers={"Authorization": f"Bearer {self.config.llm_api_key}"},
                    json=cuerpo,
                )
        except httpx.HTTPError as e:
            raise LLMNoDisponible(str(e)) from e
        if r.status_code != 200:
            raise LLMNoDisponible(f"HTTP {r.status_code}")
        datos = r.json()
        texto = datos["choices"][0]["message"]["content"].strip()
        return {"texto": texto, "modelo": datos.get("model", self.config.llm_model), "proveedor": self.config.llm_provider}
