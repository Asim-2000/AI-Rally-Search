import re
from dataclasses import dataclass


@dataclass(frozen=True)
class SpecialResponse:
    category: str
    message: str
    error_code: str | None = None


_EXACT = {
    "weather": ("weather", "Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though."),
    "what's the weather": ("weather", "Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though."),
    "what is the weather": ("weather", "Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though."),
    "how is the weather": ("weather", "Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though."),
    "hi": ("greeting", "Hello! Ready to find a rally, driver, stage, result or video?"),
    "hello": ("greeting", "Hello! Ready to find a rally, driver, stage, result or video?"),
    "hey": ("greeting", "Hello! Ready to find a rally, driver, stage, result or video?"),
    "good morning": ("greeting", "Hello! Ready to find a rally, driver, stage, result or video?"),
    "good afternoon": ("greeting", "Hello! Ready to find a rally, driver, stage, result or video?"),
    "good evening": ("greeting", "Hello! Ready to find a rally, driver, stage, result or video?"),
    "thanks": ("thanks", "Any time, navigator. See you at the next stage."),
    "thank you": ("thanks", "Any time, navigator. See you at the next stage."),
    "cheers": ("thanks", "Any time, navigator. See you at the next stage."),
    "thanks a lot": ("thanks", "Any time, navigator. See you at the next stage."),
    "who are you": ("identity", "I'm AI Rally Search — your navigator for rallies, drivers, stages, results and videos."),
    "what are you": ("identity", "I'm AI Rally Search — your navigator for rallies, drivers, stages, results and videos."),
    "what is your name": ("identity", "I'm AI Rally Search — your navigator for rallies, drivers, stages, results and videos."),
    "what can you do": ("capabilities", "I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year."),
    "help": ("capabilities", "I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year."),
    "how can you help": ("capabilities", "I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year."),
    "what do you do": ("capabilities", "I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year."),
    "tell me a joke": ("joke", "Why did the rally driver bring a pencil? To draw the perfect racing line."),
    "say something funny": ("joke", "Why did the rally driver bring a pencil? To draw the perfect racing line."),
    "rally joke": ("joke", "Why did the rally driver bring a pencil? To draw the perfect racing line."),
    "are you alive": ("alive", "Not alive, but the search engine is running. Give me a rally query and we'll hit the stage."),
    "are you real": ("alive", "Not alive, but the search engine is running. Give me a rally query and we'll hit the stage."),
}


def match_special_query(query: str) -> SpecialResponse | None:
    normalized = re.sub(r"\s+", " ", re.sub(r"[?!.,;:]+$", "", query.strip().lower()))
    exact = _EXACT.get(normalized)
    if exact:
        return SpecialResponse(*exact)
    if re.fullmatch(r"who (?:is|was) the (?:best|greatest) rally (?:driver|racer)(?: of all time)?", normalized):
        return SpecialResponse("rallyOpinion", "That's how arguments start in a service park. I can show you wins and results and let you decide.")
    if re.fullmatch(r"(?:what is|what's) the capital of [a-z ]+", normalized) or re.match(r"^(?:how do i|how to) (?:cook|bake|make)\b", normalized):
        return SpecialResponse("unsupported", "Wrong stage, navigator. I can help with rallies, drivers, stages, results and videos.", "UNSUPPORTED_QUERY")
    return None
