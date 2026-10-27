<?php

namespace App\Http\Middleware;

use App\Models\Casa;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureCasaContext
{
    public function handle(Request $request, Closure $next): Response
    {
        $rawCasaId = $request->header('X-Casa-ID');
        if ($rawCasaId === null || ! ctype_digit($rawCasaId) || (int) $rawCasaId < 1) {
            return response()->json([
                'message' => 'O header X-Casa-ID é obrigatório.',
                'type' => 'house_context_required',
                'error_code' => 'house_context_required',
            ], 400);
        }

        $casa = Casa::query()
            ->whereKey((int) $rawCasaId)
            ->whereHas('pessoas.user', fn ($query) => $query->whereKey($request->user()->id))
            ->first();

        if ($casa === null) {
            return response()->json([
                'message' => 'Recurso não encontrado.',
                'type' => 'not_found',
                'error_code' => 'house_not_found',
            ], 404);
        }

        $request->attributes->set('casa', $casa);

        return $next($request);
    }
}
