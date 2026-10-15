<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreItemRequest;
use App\Http\Requests\UpdateItemRequest;
use App\Models\Casa;
use App\Models\Audit;
use App\Models\Item;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ItemController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $casa = $this->context($request);
        $items = Item::query()
            ->where('casa_id', $casa->id)
            ->orderBy('marcado')
            ->orderBy('id')
            ->get(['id', 'nome', 'marcado', 'created_at', 'updated_at']);

        return response()->json(['data' => $items]);
    }

    public function store(StoreItemRequest $request): JsonResponse
    {
        $casa = $this->context($request);
        $nome = $request->validated('nome');
        $normalizado = $this->normalize($nome);
        $item = Item::query()
            ->where('casa_id', $casa->id)
            ->where('nome_normalizado', $normalizado)
            ->first();

        if ($item !== null) {
            return response()->json(['data' => $this->data($item)]);
        }

        try {
            $item = Item::create([
                'casa_id' => $casa->id,
                'nome' => $nome,
                'nome_normalizado' => $normalizado,
                'marcado' => false,
            ]);
        } catch (QueryException $exception) {
            $item = Item::query()
                ->where('casa_id', $casa->id)
                ->where('nome_normalizado', $normalizado)
                ->firstOrFail();

            return response()->json(['data' => $this->data($item)]);
        }

        Audit::record($request->user()->id, 'item.created', Item::class, $item->id, $casa->id, [
            'nome' => $item->nome,
            'marcado' => $item->marcado,
        ]);

        return response()->json(['data' => $this->data($item)], 201);
    }

    public function show(Request $request, int $item): JsonResponse
    {
        $itemModel = $this->itemInContext($request, $item);

        return response()->json(['data' => $this->data($itemModel)]);
    }

    public function update(UpdateItemRequest $request, int $item): \Illuminate\Http\Response
    {
        $itemModel = $this->itemInContext($request, $item);
        $data = $request->validated();

        if (array_key_exists('nome', $data)) {
            $normalizado = $this->normalize($data['nome']);
            $duplicate = Item::query()
                ->where('casa_id', $itemModel->casa_id)
                ->where('nome_normalizado', $normalizado)
                ->whereKeyNot($itemModel->id)
                ->exists();

            if ($duplicate) {
                throw ValidationException::withMessages([
                    'nome' => ['Já existe um item com esse nome nesta casa.'],
                ]);
            }

            $data['nome_normalizado'] = $normalizado;
        }

        $before = $this->data($itemModel);
        $itemModel->update($data);
        Audit::record($request->user()->id, 'item.updated', Item::class, $itemModel->id, $itemModel->casa_id, [
            'before' => $before,
            'changed' => array_intersect_key($data, array_flip(['nome', 'marcado'])),
        ]);

        return response()->noContent();
    }

    public function destroy(Request $request, int $item): \Illuminate\Http\Response
    {
        $itemModel = $this->itemInContext($request, $item);
        $before = $this->data($itemModel);
        $itemModel->delete();
        Audit::record($request->user()->id, 'item.deleted', Item::class, $itemModel->id, $itemModel->casa_id, [
            'before' => $before,
        ]);

        return response()->noContent();
    }

    private function context(Request $request): Casa
    {
        /** @var Casa $casa */
        $casa = $request->attributes->get('casa');

        return $casa;
    }

    private function itemInContext(Request $request, int $item): Item
    {
        return Item::query()
            ->whereKey($item)
            ->where('casa_id', $this->context($request)->id)
            ->firstOrFail();
    }

    /** @return array{id: int, nome: string, marcado: bool, created_at: mixed, updated_at: mixed} */
    private function data(Item $item): array
    {
        return $item->only(['id', 'nome', 'marcado', 'created_at', 'updated_at']);
    }

    private function normalize(string $name): string
    {
        return mb_strtolower((string) preg_replace('/\s+/', ' ', trim($name)));
    }
}
