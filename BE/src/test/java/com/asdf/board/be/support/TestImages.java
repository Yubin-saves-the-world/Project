package com.asdf.board.be.support;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.Random;
import javax.imageio.ImageIO;

public final class TestImages {

    private TestImages() {
    }

    public static byte[] jpeg(long seed) {
        return encode(seed, "jpg");
    }

    public static byte[] png(long seed) {
        return encode(seed, "png");
    }

    public static byte[] tinyJpeg() {
        BufferedImage image = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        return write(image, "jpg");
    }

    private static byte[] encode(long seed, String format) {
        Random random = new Random(seed);
        BufferedImage image = new BufferedImage(160, 320, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < image.getHeight(); y++) {
            for (int x = 0; x < image.getWidth(); x++) {
                image.setRGB(x, y, random.nextInt(0xFFFFFF));
            }
        }
        return write(image, format);
    }

    private static byte[] write(BufferedImage image, String format) {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            ImageIO.write(image, format, out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
