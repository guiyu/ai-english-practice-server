import { compare } from 'bcryptjs';
import prisma from '../../../utils/prisma';
import jwt from 'jsonwebtoken';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  
  const { email, password } = req.body;
  
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await compare(password, user.password))) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  const token = jwt.sign(
    { userId: user.id, plan: user.plan },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  
  res.status(200).json({ token });
}
