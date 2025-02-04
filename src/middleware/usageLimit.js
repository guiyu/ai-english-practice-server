export const usageLimit = async (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Unauthorized' });
  
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await prisma.user.findUnique({
        where: { id: decoded.userId },
        select: { plan: true, usageCount: true }
      });
  
      if (user.plan === 'free' && user.usageCount >= 10) {
        return res.status(429).json({ 
          error: 'Daily limit reached. Upgrade to continue.' 
        });
      }
      
      req.user = decoded;
      next();
    } catch (error) {
      res.status(401).json({ error: 'Invalid token' });
    }
  };
  