import jwt from 'jsonwebtoken'
import prisma from '../utils/prisma'

export const authenticate = (handler) => async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1]
  
  if (!token) {
    return res.status(401).json({ error: '未提供认证令牌' })
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET)
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId }
    })

    if (!user) {
      return res.status(401).json({ error: '用户不存在' })
    }

    req.user = user
    return handler(req, res)
  } catch (error) {
    return res.status(401).json({ error: '无效的令牌' })
  }
}
