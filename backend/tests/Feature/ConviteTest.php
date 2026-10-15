<?php

namespace Tests\Feature;

use App\Models\Casa;
use App\Models\Convite;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class ConviteTest extends TestCase
{
    use RefreshDatabase;

    public function test_member_can_create_and_another_account_can_use_a_valid_invite_once(): void
    {
        [$ownerToken, $houseId] = $this->createHouse();
        $invite = $this->withToken($ownerToken)
            ->postJson('/api/v1/casas/'.$houseId.'/convites')
            ->assertCreated()
            ->assertJsonStructure(['data' => ['id', 'codigo', 'expira_em']]);

        $code = $invite->json('data.codigo');
        $this->assertMatchesRegularExpression('/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{10}$/', $code);
        $this->assertDoesNotMatchRegularExpression('/[01ILO]/', $code);

        $guestToken = $this->register('guest@example.com');
        $this->app['auth']->forgetGuards();
        $this->withToken($guestToken)
            ->postJson('/api/v1/convites/entrar', ['codigo' => strtolower($code)])
            ->assertNoContent();

        $this->assertDatabaseHas('pessoa_casa', [
            'casa_id' => $houseId,
            'pessoa_id' => User::where('email', 'guest@example.com')->firstOrFail()->pessoa->id,
        ]);

        $secondGuestToken = $this->register('second@example.com');
        $this->app['auth']->forgetGuards();
        $this->withToken($secondGuestToken)
            ->postJson('/api/v1/convites/entrar', ['codigo' => $code])
            ->assertUnprocessable()
            ->assertJsonPath('errors.codigo.0', 'O convite é inválido, expirado, usado ou revogado.');
    }

    public function test_expired_and_revoked_invites_are_rejected(): void
    {
        [$ownerToken, $houseId] = $this->createHouse();
        $created = $this->withToken($ownerToken)
            ->postJson('/api/v1/casas/'.$houseId.'/convites')
            ->assertCreated();
        $inviteId = $created->json('data.id');
        $code = $created->json('data.codigo');

        $this->withToken($ownerToken)
            ->postJson('/api/v1/casas/'.$houseId.'/convites/'.$inviteId.'/revogar')
            ->assertNoContent();

        $guestToken = $this->register('guest@example.com');
        $this->app['auth']->forgetGuards();
        $this->withToken($guestToken)
            ->postJson('/api/v1/convites/entrar', ['codigo' => $code])
            ->assertUnprocessable();

        $fresh = Convite::create([
            'casa_id' => $houseId,
            'codigo' => 'ABCD234567',
            'expira_em' => Carbon::now()->subMinute(),
        ]);
        $otherToken = $this->register('other@example.com');
        $this->app['auth']->forgetGuards();
        $this->withToken($otherToken)
            ->postJson('/api/v1/convites/entrar', ['codigo' => $fresh->codigo])
            ->assertUnprocessable()
            ->assertJsonPath('errors.codigo.0', 'O convite é inválido, expirado, usado ou revogado.');
    }

    public function test_invite_creation_requires_house_membership(): void
    {
        [$ownerToken, $houseId] = $this->createHouse();
        $outsiderToken = $this->register('outsider@example.com');
        $this->app['auth']->forgetGuards();

        $this->withToken($outsiderToken)
            ->postJson('/api/v1/casas/'.$houseId.'/convites')
            ->assertNotFound();

        $this->app['auth']->forgetGuards();
        $this->withToken($ownerToken)
            ->postJson('/api/v1/casas/'.$houseId.'/convites')
            ->assertCreated();
    }

    private function createHouse(): array
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->withToken($token)
            ->postJson('/api/v1/casas', ['nome' => 'Casa principal'])
            ->json('data.id');

        return [$token, $houseId];
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
