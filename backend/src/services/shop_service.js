const { pool } = require('../db');

async function listItems() {
  const res = await pool.query(`SELECT id, name, price, image_url, created_at, updated_at FROM shop_items ORDER BY created_at DESC`);
  return res.rows;
}

async function getItem(id) {
  const res = await pool.query(`SELECT id, name, price, image_url, created_at, updated_at FROM shop_items WHERE id = $1`, [id]);
  return res.rows[0] || null;
}

async function createItem({ name, price, image_url }) {
  const res = await pool.query(
    `INSERT INTO shop_items (name, price, image_url) VALUES ($1, $2, $3) RETURNING id, name, price, image_url, created_at, updated_at`,
    [name, price, image_url],
  );
  return res.rows[0];
}

async function updateItem(id, { name, price, image_url }) {
  const res = await pool.query(
    `UPDATE shop_items SET name = COALESCE($2, name), price = COALESCE($3, price), image_url = COALESCE($4, image_url), updated_at = NOW() WHERE id = $1 RETURNING id, name, price, image_url, created_at, updated_at`,
    [id, name, price, image_url],
  );
  return res.rows[0] || null;
}

async function deleteItem(id) {
  await pool.query(`DELETE FROM shop_items WHERE id = $1`, [id]);
  return { deleted: true };
}

async function purchaseItem({ userId, itemId }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const userRes = await client.query(`SELECT id, coins, role FROM users WHERE id = $1 FOR UPDATE`, [userId]);
    if (userRes.rowCount === 0) throw new Error('User not found');
    const user = userRes.rows[0];

    const itemRes = await client.query(`SELECT id, price FROM shop_items WHERE id = $1`, [itemId]);
    if (itemRes.rowCount === 0) throw new Error('Item not found');
    const item = itemRes.rows[0];

    if (Number(user.coins) < Number(item.price)) {
      throw new Error('Insufficient coins');
    }

    const newCoins = Number(user.coins) - Number(item.price);
    await client.query(`UPDATE users SET coins = $2, updated_at = NOW() WHERE id = $1`, [userId, newCoins]);

    await client.query(`INSERT INTO shop_purchases (user_id, shop_item_id, price_paid) VALUES ($1, $2, $3)`, [userId, itemId, item.price]);

    await client.query(
      `INSERT INTO notifications (title, message, type, target_group, sender_id, sender_role)
       VALUES ($1, $2, 'shop_purchase', 'admins', $3, $4)`,
      [
        'Shop Purchase',
        `A ${user.role || 'user'} purchased item ${itemId} for ${item.price} coins`,
        userId,
        user.role || 'student',
      ],
    );

    await client.query('COMMIT');

    return { success: true, remaining_coins: newCoins };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  listItems,
  getItem,
  createItem,
  updateItem,
  deleteItem,
  purchaseItem,
};
