# frozen_string_literal: true

# app/services/ai/profile_service.rb
module Ai
  class ProfileService
    Error = Class.new(StandardError)

    DEFAULTS = {
      AiConstants::ProfileKey::CHAT_DEFAULT => {
        name: "Default Chat",
        temperature: AiConstants::Defaults::TEMPERATURE,
        max_output_tokens: AiConstants::Defaults::MAX_OUTPUT_TOKENS,
        context_max_tokens: AiConstants::Defaults::CONTEXT_MAX_TOKENS,
        history_max_messages: AiConstants::Defaults::HISTORY_MAX_MESSAGES,
        system_prompt: nil
      },
      AiConstants::ProfileKey::SUMMARIZE => {
        name: "Summarize",
        temperature: 0.5,
        max_output_tokens: 500,
        context_max_tokens: AiConstants::Defaults::MAX_OUTPUT_TOKENS,
        history_max_messages: 1,
        system_prompt: "Summarize the following text concisely."
      },
      AiConstants::ProfileKey::TRANSLATE => {
        name: "Translate",
        temperature: 0.3,
        max_output_tokens: 1000,
        context_max_tokens: AiConstants::Defaults::MAX_OUTPUT_TOKENS,
        history_max_messages: 1,
        system_prompt: "Translate the following text to %{language}. Return only the translation."
      },
      AiConstants::ProfileKey::ANALYZE => {
        name: "Analyze",
        temperature: 0.3,
        max_output_tokens: 500,
        context_max_tokens: AiConstants::Defaults::MAX_OUTPUT_TOKENS,
        history_max_messages: 1,
        system_prompt: "Analyze the following text and provide concise insights."
      },
      AiConstants::ProfileKey::WORD_FAMILY => {
        name: "Lesson Word Families",
        temperature: 0.3,
        max_output_tokens: 2000,
        context_max_tokens: AiConstants::Defaults::CONTEXT_MAX_TOKENS,
        history_max_messages: 1,
        system_prompt: <<~PROMPT.squish
          You extract English word families from a children's story subtitle transcript.
          Group rhyming or ending patterns such as ..et or ..ed.
          Return exactly #{LessonConstants::WordFamily::FAMILY_COUNT} word-family objects — no more, no fewer.
          Each family must have exactly #{LessonConstants::WordFamily::WORDS_PER_FAMILY} words.
          Return only a TOON array of objects with keys pattern and words (words is a list of strings).
          Do not invent words that are unrelated to the transcript. Prefer words that appear in or clearly fit the story.
        PROMPT
      },
      AiConstants::ProfileKey::STORY_ORDER => {
        name: "Lesson Story Order",
        temperature: 0.3,
        max_output_tokens: 2000,
        context_max_tokens: AiConstants::Defaults::CONTEXT_MAX_TOKENS,
        history_max_messages: 1,
        system_prompt: <<~PROMPT.squish
          You rewrite a children's story subtitle transcript into a short ordered sequence of simple English sentences
          that preserve the story order for sequencing practice.
          Return only a TOON array of sentence strings. Keep sentences short and clear. Do not add commentary.
        PROMPT
      },
      AiConstants::ProfileKey::BUILD_THE_SENTENCES => {
        name: "Lesson Build The Sentences",
        temperature: 0.3,
        max_output_tokens: 2000,
        context_max_tokens: AiConstants::Defaults::CONTEXT_MAX_TOKENS,
        history_max_messages: 1,
        system_prompt: <<~PROMPT.squish
          You build one short practice sentence for each vocabulary item using a children's story subtitle transcript.
          Return only a TOON array of objects with keys vocab and sentence.
          Emit exactly one object per vocabulary item in the same order. Each sentence must include that vocab and stay grounded in the story.
          Do not add commentary.
        PROMPT
      }
    }.freeze

    class << self
      def list(params = {})
        scope = Ai::Profile.all
        if params[:status].present? && params[:status] != "all"
          case params[:status]
          when "active", "enabled"
            scope = scope.where(enabled: true)
          when "inactive", "disabled"
            scope = scope.where(enabled: false)
          end
        elsif params[:enabled].present? && params[:enabled] != "all"
          scope = scope.where(enabled: ActiveModel::Type::Boolean.new.cast(params[:enabled]))
        end
        scope = scope.where(provider: params[:provider]) if params[:provider].present? && params[:provider] != "all"
        scope = scope.where(model: params[:model]) if params[:model].present? && params[:model] != "all"
        scope = scope.where("name ILIKE :q OR key ILIKE :q", q: "%#{params[:search]}%") if params[:search].present?
        scope
      end

      def find(id_or_key)
        if id_or_key.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          Ai::Profile.find(id_or_key)
        else
          Ai::Profile.find_by!(key: id_or_key)
        end
      end

      def create!(attributes)
        attrs = attributes.to_h.symbolize_keys
        attrs[:provider] = attrs[:provider].presence || AiConstants::Provider::DEEPSEEK
        attrs[:model] = attrs[:model].presence || AppConfig::DEEPSEEK_MODEL
        attrs[:temperature] ||= AiConstants::Defaults::TEMPERATURE
        attrs[:max_output_tokens] ||= AiConstants::Defaults::MAX_OUTPUT_TOKENS
        attrs[:context_max_tokens] ||= AiConstants::Defaults::CONTEXT_MAX_TOKENS
        attrs[:history_max_messages] ||= AiConstants::Defaults::HISTORY_MAX_MESSAGES
        attrs[:timeout_seconds] ||= AiConstants::Defaults::TIMEOUT_SECONDS
        attrs[:enabled] = true if attrs[:enabled].nil?

        Ai::Profile.create!(attrs)
      end

      def update!(profile, attributes)
        profile.update!(attributes)
        profile
      end

      def resolve!(key)
        normalized_key = key.presence || AiConstants::ProfileKey::CHAT_DEFAULT
        profile = Ai::Profile.find_by(key: normalized_key)
        if profile.nil? && AiConstants::ProfileKey::ALL.include?(normalized_key)
          profile = create_default!(normalized_key)
        end
        raise Error, "Unknown AI profile: #{normalized_key}" unless profile
        raise Error, "AI profile is disabled: #{normalized_key}" unless profile.enabled?

        profile
      end

      def create_defaults!
        AiConstants::ProfileKey::ALL.each { |key| create_default!(key) }
      end

      def prompt_for(profile, **values)
        prompt = profile.system_prompt.to_s
        return nil if prompt.blank?

        formatted_values = values.symbolize_keys.transform_values do |val|
          Ai::ToonService.json_to_toon(val)
        end

        interpolated = begin
          prompt % formatted_values
        rescue KeyError
          prompt
        end

        Ai::ToonService.json_to_toon(interpolated)
      end

      private

      def create_default!(key)
        attributes = DEFAULTS.fetch(key)
        profile = Ai::Profile.find_or_initialize_by(key: key)
        if profile.new_record?
          profile.assign_attributes(
            attributes.merge(
              provider: AiConstants::Provider::DEEPSEEK,
              model: AppConfig::DEEPSEEK_MODEL,
              enabled: true,
              timeout_seconds: AiConstants::Defaults::TIMEOUT_SECONDS
            )
          )
        else
          # Keep admin-tuned model/limits; refresh prompt + name from code defaults.
          profile.name = attributes[:name]
          profile.system_prompt = attributes[:system_prompt]
        end
        profile.save!
        profile
      end
    end
  end
end
