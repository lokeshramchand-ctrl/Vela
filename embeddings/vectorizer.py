from models.schemas import BehaviorPattern, MerchantProfile


class SemanticVectorizer:
    @staticmethod
    def stringify_profile(profile: MerchantProfile) -> str:
        """Converts a merchant profile into a dense semantic string."""
        aliases_str = ", ".join(profile.aliases)
        return (
            f"Entity: {profile.canonical_name}. "
            f"Known aliases include: {aliases_str}. "
            f"Memory State: {profile.memory_state.value}. "
            f"Transaction Frequency: Seen {profile.frequency} times. "
            f"Type: {profile.entity_type}."
        )

    @staticmethod
    def stringify_behavior(pattern: BehaviorPattern) -> str:
        """Converts mathematical behavior into a narrative string for embedding."""
        return (
            f"Behavior footprint for {pattern.merchant_name}: "
            f"Average transaction amount is {pattern.avg_amount:.2f} with a standard deviation of {pattern.std_dev:.2f}. "
            f"Preferred time of day is {pattern.preferred_hour}:00. "
            f"Weekly transaction frequency is {pattern.weekly_frequency:.2f}. "
            f"Periodicity score is {pattern.periodicity_score:.2f} (1.0 means highly predictable)."
        )

vectorizer = SemanticVectorizer()
