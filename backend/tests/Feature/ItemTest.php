<?php

namespace Tests\Feature;

use App\Models\Item;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class ItemTest extends TestCase
{
    use RefreshDatabase;

    public function test_item_requires_quantity_and_supports_optional_price_and_bought_default(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        $created = $this->asHouse($token, $houseId)->postJson('/api/v1/itens', [
            'nome' => 'Leite',
            'quantidade' => 2,
        ])->assertCreated();
        $itemId = $created->json('data.id');
        $created->assertJsonPath('data.nome', 'Leite')
            ->assertJsonPath('data.quantidade', 2)
            ->assertJsonPath('data.preco', null)
            ->assertJsonPath('data.comprado', false);
        $this->assertDatabaseHas('itens', ['id' => $itemId, 'comprado' => false]);

        $this->asHouse($token, $houseId)
            ->postJson('/api/v1/itens', ['nome' => ' leite ', 'quantidade' => 5])
            ->assertOk();
        $this->assertDatabaseCount('itens', 1);

        $this->asHouse($token, $houseId)
            ->patchJson('/api/v1/itens/'.$itemId, ['comprado' => true])
            ->assertNoContent();
        $this->asHouse($token, $houseId)
            ->getJson('/api/v1/itens')
            ->assertJsonPath('data.0.comprado', true);
    }

    public function test_item_validation_rejects_invalid_required_fields_and_price(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        foreach ([[], ['nome' => 'Leite'], ['nome' => 'Leite', 'quantidade' => 0], ['nome' => 'Leite', 'quantidade' => -1], ['nome' => 'Leite', 'quantidade' => 1, 'preco' => -1]] as $payload) {
            $this->asHouse($token, $houseId)
                ->postJson('/api/v1/itens', $payload)
                ->assertUnprocessable();
        }
    }

    public function test_cursor_pagination_returns_stable_pages_of_twenty_without_gaps(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        for ($i = 1; $i <= 45; $i++) {
            $this->asHouse($token, $houseId)
                ->postJson('/api/v1/itens', ['nome' => "Item {$i}", 'quantidade' => 1])
                ->assertCreated();
        }

        $first = $this->asHouse($token, $houseId)->getJson('/api/v1/itens')->assertOk();
        $first->assertJsonCount(20, 'data')
            ->assertJsonPath('meta.per_page', 20)
            ->assertJsonPath('meta.has_more', true);
        $cursor = $first->json('meta.next_cursor');
        $firstIds = $first->json('data.*.id');

        $second = $this->asHouse($token, $houseId)->getJson('/api/v1/itens?cursor='.urlencode($cursor))->assertOk();
        $second->assertJsonCount(20, 'data')->assertJsonPath('meta.has_more', true);
        $secondIds = $second->json('data.*.id');
        $this->assertCount(0, array_intersect($firstIds, $secondIds));

        $third = $this->asHouse($token, $houseId)->getJson('/api/v1/itens?cursor='.urlencode($second->json('meta.next_cursor')))->assertOk();
        $third->assertJsonCount(5, 'data')->assertJsonPath('meta.has_more', false)->assertJsonPath('meta.next_cursor', null);
        $this->assertCount(0, array_intersect($firstIds, $third->json('data.*.id')));
        $this->assertCount(0, array_intersect($secondIds, $third->json('data.*.id')));

        $repeat = $this->asHouse($token, $houseId)->getJson('/api/v1/itens?cursor='.urlencode($cursor))->assertOk();
        $this->assertSame($second->json('data'), $repeat->json('data'));
    }

    public function test_cursor_is_stable_when_a_new_item_is_inserted_after_first_page(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        for ($i = 1; $i <= 21; $i++) {
            $this->asHouse($token, $houseId)->postJson('/api/v1/itens', [
                'nome' => "Item {$i}", 'quantidade' => 1,
            ]);
        }
        $first = $this->asHouse($token, $houseId)->getJson('/api/v1/itens');
        $cursor = $first->json('meta.next_cursor');
        $this->asHouse($token, $houseId)->postJson('/api/v1/itens', ['nome' => 'Novo', 'quantidade' => 1])->assertCreated();

        $second = $this->asHouse($token, $houseId)->getJson('/api/v1/itens?cursor='.urlencode($cursor))->assertOk();
        $this->assertCount(1, $second->json('data'));
        $this->assertSame('Item 1', $second->json('data.0.nome'));
    }

    public function test_invalid_cursor_returns_a_sanitized_bad_request(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        $this->asHouse($token, $houseId)
            ->getJson('/api/v1/itens?cursor=not-a-cursor')
            ->assertBadRequest()
            ->assertJsonPath('type', 'bad_request')
            ->assertJsonPath('error_code', 'cursor_invalid');
    }

    public function test_item_access_stays_scoped_to_selected_house(): void
    {
        $firstToken = $this->register('first@example.com');
        $firstHouse = $this->createHouse($firstToken, 'Primeira');
        $secondToken = $this->register('second@example.com');
        $secondHouse = $this->createHouse($secondToken, 'Segunda');

        $firstItem = $this->asHouse($firstToken, $firstHouse)
            ->postJson('/api/v1/itens', ['nome' => 'Arroz', 'quantidade' => 1])
            ->assertCreated();
        $this->asHouse($secondToken, $secondHouse)
            ->getJson('/api/v1/itens/'.$firstItem->json('data.id'))
            ->assertNotFound();
    }

    public function test_item_routes_require_selected_house_context(): void
    {
        $token = $this->register('owner@example.com');

        $this->withToken($token)
            ->getJson('/api/v1/itens')
            ->assertBadRequest()
            ->assertJsonPath('type', 'house_context_required');
    }

    private function asHouse(string $token, int $houseId): self
    {
        return $this->withToken($token)->withHeader('X-Casa-ID', (string) $houseId);
    }

    private function createHouse(string $token, string $name): int
    {
        return $this->withToken($token)->postJson('/api/v1/casas', ['nome' => $name])->json('data.id');
    }

    private function register(string $email): string
    {
        return $this->postJson('/api/v1/auth/register', [
            'name' => 'Person', 'email' => $email,
            'password' => 'secret-password', 'password_confirmation' => 'secret-password',
        ])->json('data.token');
    }
}
