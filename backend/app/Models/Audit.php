<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Audit extends Model
{
    protected $fillable = [
        'user_id',
        'casa_id',
        'action',
        'auditable_type',
        'auditable_id',
        'changes',
    ];

    protected function casts(): array
    {
        return ['changes' => 'array'];
    }

    public static function record(
        int $userId,
        string $action,
        string $auditableType,
        int $auditableId,
        ?int $casaId,
        array $changes = [],
    ): self {
        return self::create([
            'user_id' => $userId,
            'casa_id' => $casaId,
            'action' => $action,
            'auditable_type' => $auditableType,
            'auditable_id' => $auditableId,
            'changes' => $changes,
        ]);
    }
}
