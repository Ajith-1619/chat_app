<?php
declare(strict_types=1);

final class FlowAutoTranslatePlugin
{
    public function handle(string $hook, array $event, FlowPluginContext $context): void
    {
        if ($hook !== 'message.received') return;
        $message = $event['message'] ?? [];
        $body = trim((string)($message['body'] ?? ''));
        $messageId = (string)($message['id'] ?? '');
        if ($body === '' || $messageId === '') return;

        // Example-only translator. Production plugins can call an external AI/translation
        // service from inside this plugin without changing Messenger core.
        $translated = $this->translateToEnglish($body);
        if ($translated === $body) return;

        $context->saveArtifact(
            $hook,
            'message',
            $messageId,
            'translation',
            [
                'source_language' => 'auto',
                'target_language' => 'en',
                'source_text' => $body,
                'translated_text' => $translated,
                'provider' => 'flow-example-local',
            ]
        );
    }

    private function translateToEnglish(string $text): string
    {
        $dictionary = [
            'vanakkam' => 'hello',
            'nandri' => 'thank you',
            'seri' => 'ok',
            'epdi irukka' => 'how are you',
            'pannidu' => 'please do it',
            'mudiyuma' => 'is it possible',
        ];
        $translated = $text;
        foreach ($dictionary as $source => $target) {
            $translated = str_ireplace($source, $target, $translated);
        }
        return $translated;
    }
}
