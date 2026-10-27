<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ItemTest extends TestCase
{
    use RefreshDatabase;

    public function test_member_can_crud_and_toggle_items_in_the_selected_house(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        $created = $this->asHouse($token, $houseId)->postJson('/api/v1/itens', [
            'nome' => 'Leite',
        ])->assertCreated();
        $itemId = $created->json('data.id');
        $created->assertJsonPath('data.nome', 'Leite')
            ->assertJsonPath('data.marcado', false);

        $this->asHouse($token, $houseId)
            ->postJson('/api/v1/itens', ['nome' => ' leite '])
            ->assertOk();
        $this->assertDatabaseCount('itens', 1);

        $this->asHouse($token, $houseId)
            ->getJson('/api/v1/itens')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->asHouse($token, $houseId)
            ->patchJson('/api/v1/itens/'.$itemId, ['marcado' => true])
            ->assertNoContent();

        $this->asHouse($token, $houseId)
            ->getJson('/api/v1/itens')
            ->assertJsonPath('data.0.marcado', true);

        $this->asHouse($token, $houseId)
            ->patchJson('/api/v1/itens/'.$itemId, ['nome' => 'Leite integral'])
            ->assertNoContent();

        $this->asHouse($token, $houseId)
            ->deleteJson('/api/v1/itens/'.$itemId)
            ->assertNoContent();
        $this->assertDatabaseCount('itens', 0);
    }

    public function test_same_item_can_exist_once_per_house_but_not_be_cross_read(): void
    {
        $firstToken = $this->register('first@example.com');
        $firstHouse = $this->createHouse($firstToken, 'Primeira');
        $secondToken = $this->register('second@example.com');
        $secondHouse = $this->createHouse($secondToken, 'Segunda');

        $firstItem = $this->asHouse($firstToken, $firstHouse)
            ->postJson('/api/v1/itens', ['nome' => 'Arroz'])
            ->assertCreated();
        $this->asHouse($secondToken, $secondHouse)
            ->postJson('/api/v1/itens', ['nome' => 'Arroz'])
            ->assertCreated();

        $this->app['auth']->forgetGuards();
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

    public function test_item_contract_exposes_ok_empty_and_house_error_states(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        $this->asHouse($token, $houseId)
            ->getJson('/api/v1/casa-atual')
            ->assertOk()
            ->assertJsonStructure(['data' => ['id', 'nome', 'created_at']]);

        $this->asHouse($token, $houseId)
            ->getJson('/api/v1/itens')
            ->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonStructure(['data']);

        $this->withToken($token)
            ->withHeader('X-Casa-ID', '999999')
            ->getJson('/api/v1/itens')
            ->assertNotFound()
            ->assertJsonPath('error_code', 'house_not_found')
            ->assertJsonMissingPath('data');
    }

    private function asHouse(string $token, int $houseId): self
    {
        return $this->withToken($token)->withHeader('X-Casa-ID', (string) $houseId);
    }

    private function createHouse(string $token, string $name): int
    {
        return $this->withToken($token)
            ->postJson('/api/v1/casas', ['nome' => $name])
            ->json('data.id');
    }

    private function register(string $email): string
    {
        return $this->postJson('/api/v1/auth/register', [
            'name' => 'Person',
            'email' => $email,
            'password' => 'secret-password',
            'password_confirmation' => 'secret-password',
        ])->json('data.token');
    }
}
