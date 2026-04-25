const express = require('express');
const { authenticate, requireRole } = require('../middleware/auth');
const shopService = require('../services/shop_service');

const router = express.Router();
router.use(authenticate);

// Public to authenticated users: list items
router.get('/shop/items', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  try {
    const items = await shopService.listItems();
    res.json(items);
  } catch (err) {
    console.error('[SHOP] list items failed:', err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// Admin CRUD
router.post('/admin/shop/items', requireRole('admin'), async (req, res) => {
  const { name, price, image_url } = req.body || {};
  if (!name || typeof price === 'undefined') return res.status(400).json({ message: 'name and price required' });
  try {
    const item = await shopService.createItem({ name, price: Number(price), image_url });
    return res.status(201).json(item);
  } catch (err) {
    console.error('[SHOP] create item failed:', err.message);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.put('/admin/shop/items/:id', requireRole('admin'), async (req, res) => {
  try {
    const updated = await shopService.updateItem(req.params.id, req.body || {});
    if (!updated) return res.status(404).json({ message: 'Not found' });
    return res.json(updated);
  } catch (err) {
    console.error('[SHOP] update item failed:', err.message);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.delete('/admin/shop/items/:id', requireRole('admin'), async (req, res) => {
  try {
    await shopService.deleteItem(req.params.id);
    return res.json({ deleted: true });
  } catch (err) {
    console.error('[SHOP] delete item failed:', err.message);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Purchase
router.post('/shop/purchase', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  const userId = req.user.id;
  const { item_id } = req.body || {};
  if (!item_id) return res.status(400).json({ message: 'item_id required' });
  try {
    const result = await shopService.purchaseItem({ userId, itemId: item_id });
    // Optionally, notify admin via events table
    return res.json(result);
  } catch (err) {
    console.error('[SHOP] purchase failed:', err.message);
    if (err.message === 'Insufficient coins') return res.status(400).json({ message: err.message });
    if (err.message === 'User not found' || err.message === 'Item not found') return res.status(404).json({ message: err.message });
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
