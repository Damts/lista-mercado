<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class EntrarConviteRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $this->merge(['codigo' => strtoupper(trim((string) $this->input('codigo')))]);
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'codigo' => ['required', 'string', 'size:10', 'regex:/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{10}$/'],
        ];
    }
}
