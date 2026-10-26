package com.asdf.board.be.community.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.community.entity.Block;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BlockRepository extends JpaRepository<Block, Block.Key> {

    @Query("select b.id.blockedId from Block b where b.id.blockerId = :blockerId")
    List<Long> blockedIds(@Param("blockerId") Long blockerId);

    @Query(value = "select b from Block b join fetch b.blocked where b.id.blockerId = :blockerId order by b.createdAt desc, b.id.blockedId desc",
            countQuery = "select count(b) from Block b where b.id.blockerId = :blockerId")
    Page<Block> findOfBlocker(@Param("blockerId") Long blockerId, Pageable pageable);

    @BulkWrite
    @Query("delete from Block b where b.id.blockerId = :blockerId and b.id.blockedId = :blockedId")
    void deleteOne(@Param("blockerId") Long blockerId, @Param("blockedId") Long blockedId);
}
