from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""

    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-5"

    public_base_url: str = "http://localhost:8000"
    company_name: str = "الشركة"
    call_language: str = "ar-SA"
    tts_voice: str = "Polly.Zeina"

    call_window_start_hour: int = 9
    call_window_end_hour: int = 20

    database_path: str = "./data/calls.db"

    max_conversation_turns: int = 12


settings = Settings()
