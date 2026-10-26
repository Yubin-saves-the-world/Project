package com.asdf.board.be.global.storage;

public interface PhotoStorage {

    void put(String key, byte[] data);

    byte[] get(String key);

    void delete(String key);
}
