"""Configuración desde variables de entorno (/srv/atlas/config/atlas.conf). Sin secretos en el código."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str
    llm_provider: str
    llm_api_url: str
    llm_api_key: str
    llm_model: str
    llm_timeout: float
    ml_min_estudiantes: int
    ml_min_intentos: int

    @staticmethod
    def desde_entorno() -> "Config":
        e = os.environ
        return Config(
            db_host=e.get("ATLAS_DB_HOST", "atlas-db"),
            db_port=int(e.get("ATLAS_DB_PORT", "3306")),
            db_name=e.get("ATLAS_DB_NAME", "atlas_db"),
            db_user=e.get("ATLAS_DB_ANALYSIS_USER", "atlas_analysis"),
            db_password=e.get("ATLAS_DB_ANALYSIS_PASSWORD", ""),
            llm_provider=e.get("LLM_PROVIDER", "groq"),
            llm_api_url=e.get("LLM_API_URL", "https://api.groq.com/openai/v1"),
            llm_api_key=e.get("LLM_API_KEY", ""),
            llm_model=e.get("LLM_MODEL", "llama-3.3-70b-versatile"),
            llm_timeout=float(e.get("LLM_TIMEOUT", "25")),
            ml_min_estudiantes=int(e.get("ML_MIN_ESTUDIANTES", "20")),
            ml_min_intentos=int(e.get("ML_MIN_INTENTOS_POR_ESTUDIANTE", "5")),
        )
