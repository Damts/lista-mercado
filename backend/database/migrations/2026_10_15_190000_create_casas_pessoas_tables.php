<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('casas', function (Blueprint $table): void {
            $table->id();
            $table->string('nome', 120);
            $table->timestamps();
        });

        Schema::create('pessoas', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->timestamps();
        });

        Schema::create('pessoa_casa', function (Blueprint $table): void {
            $table->foreignId('pessoa_id')->constrained('pessoas')->cascadeOnDelete();
            $table->foreignId('casa_id')->constrained('casas')->cascadeOnDelete();
            $table->primary(['pessoa_id', 'casa_id']);
        });

        foreach (DB::table('users')->pluck('id') as $userId) {
            DB::table('pessoas')->insert([
                'user_id' => $userId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('pessoa_casa');
        Schema::dropIfExists('pessoas');
        Schema::dropIfExists('casas');
    }
};
