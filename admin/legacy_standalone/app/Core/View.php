<?php
declare(strict_types=1);

final class View
{
    public static function render(string $view, array $data = [], string $layout = 'admin'): void
    {
        $viewPath = __DIR__ . '/../Views/' . str_replace('.', '/', $view) . '.php';
        if (!is_file($viewPath)) {
            throw new RuntimeException('View not found: ' . $view);
        }

        extract($data, EXTR_SKIP);
        ob_start();
        require $viewPath;
        $content = (string)ob_get_clean();

        $layoutPath = __DIR__ . '/../Views/layouts/' . $layout . '.php';
        if (!is_file($layoutPath)) {
            echo $content;
            return;
        }

        require $layoutPath;
    }
}
