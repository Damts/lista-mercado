<?php

namespace Tests\Feature;

use App\Models\Audit;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditTest extends TestCase
{
    use RefreshDatabase;

    public function test_sensitive_mutations_are_audited_without_credentials(): void
    {
        $token = $this->register('owner@example.com');
        $house = $this->withToken($token)
            ->postJson('/api/v1/casas', ['nome' => 'Casa'])
            ->json('data.id');

        $this->withToken($token)
            ->withHeader('X-Casa-ID', (string) $house)
            ->postJson('/api/v1/itens', ['nome' => 'Arroz', 'quantidade' => 1])
            ->assertCreated();

        $audits = Audit::query()->get();
        $this->assertTrue($audits->contains('action', 'casa.created'));
        $this->assertTrue($audits->contains('action', 'item.created'));
        $this->assertStringNotContainsString('secret-password', $audits->toJson());
        $this->assertStringNotContainsString($token, $audits->toJson());
    }

    public function test_unauthenticated_api_response_is_sanitized(): void
    {
        $this->getJson('/api/v1/itens')
            ->assertUnauthorized()
            ->assertJson([
                'message' => 'Autenticação necessária.',
                'type' => 'unauthenticated',
            ]);
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
