package com.asdf.board.be.community.repository;

import com.asdf.board.be.community.entity.Block;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BlockRepository extends JpaRepository<Block, Block.Key> {

    boolean existsByBlockerIdAndBlockedId(Long blockerId, Long blockedId);

    void deleteByBlockerIdAndBlockedId(Long blockerId, Long blockedId);

    @Query("SELECT b FROM Block b JOIN FETCH b.blocked WHERE b.blocker.id = :blockerId ORDER BY b.createdAt DESC")
    Page<Block> findByBlockerId(@Param("blockerId") Long blockerId, Pageable pageable);
}
