<?php

use App\Http\Middleware\EnsureCasaContext;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'casa.context' => EnsureCasaContext::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (\Illuminate\Validation\ValidationException $exception, \Illuminate\Http\Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => 'Os dados enviados são inválidos.',
                    'type' => 'validation_error',
                    'error_code' => 'validation_error',
                    'errors' => $exception->errors(),
                ], 422);
            }
        });

        $exceptions->render(function (\Symfony\Component\HttpKernel\Exception\NotFoundHttpException $exception, \Illuminate\Http\Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => 'Recurso não encontrado.',
                    'type' => 'not_found',
                    'error_code' => 'resource_not_found',
                ], 404);
            }
        });

        $exceptions->render(function (\Symfony\Component\HttpKernel\Exception\BadRequestHttpException $exception, \Illuminate\Http\Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => $exception->getMessage() ?: 'Requisição inválida.',
                    'type' => 'bad_request',
                    'error_code' => 'cursor_invalid',
                ], 400);
            }
        });

        $exceptions->render(function (\Illuminate\Auth\AuthenticationException $exception, \Illuminate\Http\Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => 'Autenticação necessária.',
                    'type' => 'unauthenticated',
                    'error_code' => 'unauthenticated',
                ], 401);
            }
        });

        $exceptions->render(function (\Throwable $exception, \Illuminate\Http\Request $request) {
            if ($request->is('api/*')) {
                report($exception);

                return response()->json([
                    'message' => 'Ocorreu um erro interno.',
                    'type' => 'internal_error',
                    'error_code' => 'internal_error',
                ], 500);
            }
        });
    })->create();
