const request = require('supertest');
const { add, subtract, multiply, divide, calculate } = require('../app/calculator');
const app = require('../app/index');

describe('Calculator unit tests', () => {
  test('add: 2 + 3 = 5', () => {
    expect(add(2, 3)).toBe(5);
  });

  test('add: negative numbers', () => {
    expect(add(-4, -6)).toBe(-10);
  });

  test('subtract: 10 - 4 = 6', () => {
    expect(subtract(10, 4)).toBe(6);
  });

  test('multiply: 3 * 7 = 21', () => {
    expect(multiply(3, 7)).toBe(21);
  });

  test('divide: 10 / 2 = 5', () => {
    expect(divide(10, 2)).toBe(5);
  });

  test('divide by zero throws error', () => {
    expect(() => divide(5, 0)).toThrow('Division by zero is not allowed');
  });

  test('calculate: uses + operator', () => {
    expect(calculate(1, 2, '+')).toBe(3);
  });

  test('calculate: uses - operator', () => {
    expect(calculate(9, 4, '-')).toBe(5);
  });

  test('calculate: uses * operator', () => {
    expect(calculate(6, 6, '*')).toBe(36);
  });

  test('calculate: uses / operator', () => {
    expect(calculate(15, 3, '/')).toBe(5);
  });

  test('calculate: unknown operator throws', () => {
    expect(() => calculate(1, 2, '^')).toThrow('Unknown operator');
  });

  test('calculate: floating point result', () => {
    expect(calculate(1, 3, '/')).toBeCloseTo(0.333, 2);
  });
});

describe('API integration tests', () => {
  test('POST /calculate returns correct result', async () => {
    const res = await request(app)
      .post('/calculate')
      .send({ a: 5, b: 3, op: '+' });

    expect(res.status).toBe(200);
    expect(res.body.result).toBe(8);
    expect(res.body.expression).toBe('5 + 3 = 8');
  });

  test('POST /calculate division', async () => {
    const res = await request(app)
      .post('/calculate')
      .send({ a: 10, b: 4, op: '/' });

    expect(res.status).toBe(200);
    expect(res.body.result).toBe(2.5);
  });

  test('POST /calculate division by zero returns 400', async () => {
    const res = await request(app)
      .post('/calculate')
      .send({ a: 5, b: 0, op: '/' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/zero/i);
  });

  test('POST /calculate missing params returns 400', async () => {
    const res = await request(app)
      .post('/calculate')
      .send({ a: 5 });

    expect(res.status).toBe(400);
  });

  test('POST /calculate invalid number returns 400', async () => {
    const res = await request(app)
      .post('/calculate')
      .send({ a: 'abc', b: 3, op: '+' });

    expect(res.status).toBe(400);
  });

  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body).toHaveProperty('uptime');
    expect(res.body).toHaveProperty('version');
  });
});
