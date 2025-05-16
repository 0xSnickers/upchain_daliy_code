import MintNFTComponent from '@/components/MintNFT'
import { BASE_ERC721_ADDRESS, ERC721_NFT_ABI } from "@/config"
function MintNFT() {
    return (
        <MintNFTComponent nftABI={ERC721_NFT_ABI} nftAddress={BASE_ERC721_ADDRESS} />
    )
}

export default MintNFT