import { describe, expect, it } from 'vitest';
import { signInErrorText } from './auth';

describe('signInErrorText', () => {
  it('explains Firebase errors in Russian', () => {
    expect(signInErrorText({ code: 'auth/invalid-credential' })).toBe('Неверный e-mail или пароль.');
    expect(signInErrorText({ code: 'auth/wrong-password' })).toBe('Неверный e-mail или пароль.');
    expect(signInErrorText({ code: 'auth/too-many-requests' })).toMatch(/Слишком много попыток/);
    expect(signInErrorText({ code: 'auth/network-request-failed' })).toMatch(/Нет связи/);
    expect(signInErrorText({ code: 'auth/operation-not-allowed' })).toMatch(/выключен в настройках Firebase/);
  });

  it('shows an unknown code as it is', () => {
    expect(signInErrorText({ code: 'auth/quota-exceeded' })).toBe('Не удалось войти (auth/quota-exceeded).');
    expect(signInErrorText(new Error('boom'))).toBe('Не удалось войти. Попробуйте ещё раз.');
  });
});
