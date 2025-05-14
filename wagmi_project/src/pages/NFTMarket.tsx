import NFTMarketComponent from '@/components/NFTMarket'
import { BASE_ERC721_ADDRESS, NFT_MARKET_ADDRESS } from "@/config"

function NFTMarket() {
    return (
        <NFTMarketComponent marketAddress={NFT_MARKET_ADDRESS} nftAddress={BASE_ERC721_ADDRESS}/>
    )
}

export default NFTMarket