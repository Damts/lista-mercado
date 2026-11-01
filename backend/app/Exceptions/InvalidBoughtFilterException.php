<?php

namespace App\Exceptions;

use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

final class InvalidBoughtFilterException extends BadRequestHttpException
{
    public function __construct()
    {
        parent::__construct('Parâmetro comprado inválido.');
    }
}
