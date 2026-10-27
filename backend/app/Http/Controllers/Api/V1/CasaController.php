<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCasaRequest;
use App\Models\Casa;
use App\Models\Audit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CasaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $casas = Casa::query()
            ->whereHas('pessoas.user', fn ($query) => $query->whereKey($request->user()->id))
            ->orderBy('id')
            ->get(['id', 'nome', 'created_at']);

        return response()->json(['data' => $casas]);
    }

    public function store(StoreCasaRequest $request): JsonResponse
    {
        $casa = Casa::create($request->validated());
        $request->user()->pessoa->casas()->attach($casa->id);
        Audit::record($request->user()->id, 'casa.created', Casa::class, $casa->id, $casa->id, [
            'nome' => $casa->nome,
        ]);

        return response()->json(['data' => $casa->only(['id', 'nome', 'created_at'])], 201);
    }

    public function show(Request $request, int $casa): JsonResponse
    {
        $casaModel = Casa::query()
            ->whereKey($casa)
            ->whereHas('pessoas.user', fn ($query) => $query->whereKey($request->user()->id))
            ->first(['id', 'nome', 'created_at']);

        if ($casaModel === null) {
            return response()->json([
                'message' => 'Recurso não encontrado.',
                'type' => 'not_found',
                'error_code' => 'house_not_found',
            ], 404);
        }

        return response()->json(['data' => $casaModel]);
    }
}
