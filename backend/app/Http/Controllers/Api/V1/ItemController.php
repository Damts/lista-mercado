<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreItemRequest;
use App\Http\Requests\UpdateItemRequest;
use App\Models\Audit;
use App\Models\Casa;
use App\Models\Item;
use Carbon\CarbonImmutable;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

class ItemController extends Controller
{
    private const PAGE_SIZE = 20;

    public function index(Request $request): JsonResponse
    {
        $casa = $this->context($request);
        $cursor = $this->decodeCursor($request->query('cursor'));

        $query = Item::query()
            ->where('casa_id', $casa->id)
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($cursor !== null) {
            $query->where(function ($query) use ($cursor): void {
                $query->where('created_at', '<', $cursor['created_at'])
                    ->orWhere(function ($query) use ($cursor): void {
                        $query->where('created_at', '=', $cursor['created_at'])
                            ->where('id', '<', $cursor['id']);
                    });
            });
        }

        $items = $query
            ->limit(self::PAGE_SIZE + 1)
            ->get(['id', 'nome', 'quantidade', 'preco', 'comprado', 'created_at', 'updated_at']);
        $hasMore = $items->count() > self::PAGE_SIZE;
        $page = $items->take(self::PAGE_SIZE)->values();
        $last = $page->last();

        return response()->json([
            'data' => $page->map(fn (Item $item): array => $this->data($item))->all(),
            'meta' => [
                'per_page' => self::PAGE_SIZE,
                'has_more' => $hasMore,
                'next_cursor' => $hasMore && $last instanceof Item ? $this->encodeCursor($last) : null,
            ],
        ]);
    }

    public function store(StoreItemRequest $request): JsonResponse
    {
        $casa = $this->context($request);
        $data = $request->validated();
        $normalizado = $this->normalize($data['nome']);
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
                'nome' => $data['nome'],
                'nome_normalizado' => $normalizado,
                'quantidade' => $data['quantidade'],
                'preco' => $data['preco'] ?? null,
                'comprado' => false,
            ]);
        } catch (QueryException) {
            $item = Item::query()
                ->where('casa_id', $casa->id)
                ->where('nome_normalizado', $normalizado)
                ->firstOrFail();

            return response()->json(['data' => $this->data($item)]);
        }

        Audit::record($request->user()->id, 'item.created', Item::class, $item->id, $casa->id, [
            'nome' => $item->nome,
            'quantidade' => $item->quantidade,
            'preco' => $item->preco,
            'comprado' => $item->comprado,
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
            'changed' => array_intersect_key($data, array_flip(['nome', 'quantidade', 'preco', 'comprado'])),
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
        return $request->attributes->get('casa');
    }

    private function itemInContext(Request $request, int $item): Item
    {
        return Item::query()
            ->whereKey($item)
            ->where('casa_id', $this->context($request)->id)
            ->firstOrFail();
    }

    /** @return array{id: int, nome: string, quantidade: int, preco: string|null, comprado: bool, created_at: mixed, updated_at: mixed} */
    private function data(Item $item): array
    {
        return $item->only(['id', 'nome', 'quantidade', 'preco', 'comprado', 'created_at', 'updated_at']);
    }

    private function encodeCursor(Item $item): string
    {
        return base64_encode(json_encode([
            'created_at' => $item->getRawOriginal('created_at'),
            'id' => $item->id,
        ], JSON_THROW_ON_ERROR));
    }

    /** @return array{created_at: string, id: int}|null */
    private function decodeCursor(?string $encoded): ?array
    {
        if ($encoded === null) {
            return null;
        }

        $decoded = base64_decode($encoded, true);
        $payload = $decoded === false ? null : json_decode($decoded, true);

        if (!is_array($payload) || !isset($payload['created_at'], $payload['id']) || !is_int($payload['id'])) {
            throw new BadRequestHttpException('Cursor inválido.');
        }

        try {
            $createdAt = CarbonImmutable::parse($payload['created_at'])->format('Y-m-d H:i:s');
        } catch (\Throwable) {
            throw new BadRequestHttpException('Cursor inválido.');
        }

        return ['created_at' => $createdAt, 'id' => $payload['id']];
    }

    private function normalize(string $name): string
    {
        return mb_strtolower((string) preg_replace('/\s+/', ' ', trim($name)));
    }
}
